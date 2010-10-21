package Lacuna::DB::Result::Building::Shipyard;

use Moose;
use utf8;
no warnings qw(uninitialized);
extends 'Lacuna::DB::Result::Building';
use Lacuna::Util qw(format_date);
use DateTime;

around 'build_tags' => sub {
    my ($orig, $class) = @_;
    return ($orig->($class), qw(Infrastructure Ships));
};


sub get_ship_costs {
    my ($self, $ship) = @_;
    my $body = $self->body;
    my $percentage_of_cost = 100; 
    if ($ship->base_hold_size) {
        my $trade = $self->trade_ministry;
        if (defined $trade) {
            $percentage_of_cost += $trade->level * 3;
        }
    }
    if ($ship->base_stealth) {
        my $cloak = $self->cloaking_lab;
        if (defined $cloak) {
            $percentage_of_cost += $cloak->level * 3;
        }
    }
    if ($ship->pilotable) {
        my $pilot = $self->pilot_training_facility;
        if (defined $pilot) {
            $percentage_of_cost += $pilot->level * 3;
        }
    }
    my $propulsion = $self->propulsion_factory;
    if (defined $propulsion) {
        $percentage_of_cost += $propulsion->level * 3;
    }
    $percentage_of_cost /= 100;
    return {
        seconds => sprintf('%0.f', $ship->base_time_cost * $self->time_cost_reduction_bonus($self->level * 3)),
        food    => sprintf('%0.f', $ship->base_food_cost * $percentage_of_cost * $self->manufacturing_cost_reduction_bonus),
        water   => sprintf('%0.f', $ship->base_water_cost * $percentage_of_cost * $self->manufacturing_cost_reduction_bonus),
        ore     => sprintf('%0.f', $ship->base_ore_cost * $percentage_of_cost * $self->manufacturing_cost_reduction_bonus),
        energy  => sprintf('%0.f', $ship->base_energy_cost * $percentage_of_cost * $self->manufacturing_cost_reduction_bonus),
        waste   => sprintf('%0.f', $ship->base_waste_cost * $percentage_of_cost),
    };
}

has max_ships => (
    is  => 'ro',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return Lacuna->db->resultset('Lacuna::DB::Result::Building')->search( { class => $self->class, body_id => $self->body_id } )->get_column('level')->sum;
    },
);

sub can_build_ship {
    my ($self, $ship, $costs) = @_;
    if (ref $ship eq 'Lacuna::DB::Result::Ships') {
        confess [1002, 'That is an unknown ship type.'];
    }
    $ship->body_id($self->body_id);
    my $ships = Lacuna->db->resultset('Lacuna::DB::Result::Ships');
    $costs ||= $self->get_ship_costs($ship);
    if ($ship->type ~~ [qw(space_station)]) {
        confess [1010, 'Not yet implemented.'];
    }
    if ($self->level < 1) {
        confess [1013, "You can't build a ship if the shipyard isn't complete."];
    }
    my $body = $self->body;
    foreach my $key (keys %{$costs}) {
        next if ($key eq 'seconds' || $key eq 'waste');
        my $cost = $costs->{$key};
        unless ($cost <= $body->type_stored($key)) {
            confess [1011, 'Not enough resources.', $key];
        }
    }
    my $ships_building = $ships->search({body_id => $self->body_id, task=>'Building'})->count;
    if ($ships_building >= $self->max_ships) {
        confess [1013, 'You can only have '.$self->max_ships.' ships in the queue at this shipyard. Upgrade the shipyard to support more ships.']
    }
    my $count = Lacuna->db->resultset('Lacuna::DB::Result::Building')->search( { body_id => $self->body_id, class => $ship->prereq->{class}, level => {'>=' => $ship->prereq->{level}} } )->count;
    unless ($count) {
        confess [1013, 'You need a level '.$ship->prereq->{level}.' '.$ship->prereq->{class}->name.' to build this ship.'];
    }
    unless ($self->body->spaceport->docks_available) {
        confess [1009, 'You do not have a dock available at the Spaceport.'];
    }
    return 1;
}


sub build_ship {
    my ($self, $ship, $time) = @_;
    $ship->task('Building');
    my $name = $ship->type_formatted . ' '. $self->level;
    $ship->name($name);
    $ship->body_id($self->body_id);
    $self->set_ship_speed($ship);
    $self->set_ship_hold_size($ship);
    $self->set_ship_stealth($ship);
    $time ||= $self->get_ship_costs($ship)->{seconds};
    my $latest = Lacuna->db->resultset('Lacuna::DB::Result::Ships')->search(
        { body_id => $self->body_id, task => 'Building' },
        { order_by    => { -desc => 'date_available' }, rows=>1},
        )->single;
    my $date_completed;
    if (defined $latest) {
        $date_completed = $latest->date_available->clone;
    }
    else {
        $date_completed = DateTime->now;
    }
    $date_completed->add(seconds=>$time);
    $ship->date_available($date_completed);
    $ship->date_started(DateTime->now);
    $ship->insert;
    return $ship;
}

use constant controller_class => 'Lacuna::RPC::Building::Shipyard';

use constant building_prereq => {'Lacuna::DB::Result::Building::SpacePort'=>1};

use constant image => 'shipyard';

use constant name => 'Shipyard';

use constant food_to_build => 75;

use constant energy_to_build => 75;

use constant ore_to_build => 75;

use constant water_to_build => 75;

use constant waste_to_build => 100;

use constant time_to_build => 150;

use constant food_consumption => 4;

use constant energy_consumption => 6;

use constant ore_consumption => 6;

use constant water_consumption => 4;

use constant waste_production => 2;

use constant star_to_body_distance_ratio => 100;


has cloaking_lab => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->body->get_building_of_class('Lacuna::DB::Result::Building::CloakingLab');
    },
);

has pilot_training_facility => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->body->get_building_of_class('Lacuna::DB::Result::Building::PilotTraining');
    },
);

has propulsion_factory => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->body->get_building_of_class('Lacuna::DB::Result::Building::Propulsion');
    },
);

has trade_ministry => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->body->get_building_of_class('Lacuna::DB::Result::Building::Trade');
    },
);

sub set_ship_speed {
    my ($self, $ship) = @_;
    my $base_speed = $ship->base_speed;
    my $propulsion_level = (defined $self->propulsion_factory) ? $self->propulsion_factory->level : 0;
    my $ptf = ($ship->pilotable && defined $self->pilot_training_facility) ? $self->pilot_training_facility->level : 0;
    my $speed_improvement = ($ptf * 3) + ($propulsion_level * 5) + ($self->body->empire->science_affinity * 3);
    $ship->speed(sprintf('%.0f', $base_speed * ((100 + $speed_improvement) / 100)));
    return $ship->speed;
}

sub set_ship_hold_size {
    my ($self, $ship) = @_;
    my $trade_ministry_level = (defined $self->trade_ministry) ? $self->trade_ministry->level : 0;
    my $bonus = $self->body->empire->trade_affinity * $trade_ministry_level;
    $ship->hold_size(sprintf('%.0f', $ship->base_hold_size * $bonus));
    return $ship->hold_size;
}

sub set_ship_stealth {
    my ($self, $ship) = @_;
    my $cloaking_level = (defined $self->cloaking_lab) ? $self->cloaking_lab->level : 1;
    my $ptf = ($ship->pilotable && defined $self->pilot_training_facility) ? $self->pilot_training_facility->level : 1;
    my $bonus = $self->body->empire->deception_affinity * $cloaking_level * $ptf;
    $ship->stealth(sprintf('%.0f', $ship->base_stealth + $bonus));
    return $ship->stealth;
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
