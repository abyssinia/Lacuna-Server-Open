package Lacuna::RPC::Building::MassadsHenge;

use Moose;
use utf8;
no warnings qw(uninitialized);
extends 'Lacuna::RPC::Building';

sub app_url {
    return '/massadshenge';
}

sub model_class {
    return 'Lacuna::DB::Result::Building::Permanent::MassadsHenge';
}


sub view_planet_incoming {
    my ($self, $session_id, $building_id, $planet_id, $page_number) = @_;
    my $empire = $self->get_empire_by_session($session_id);
    my $building = $self->get_building($empire, $building_id);
    my $planet = Lacuna->db->resultset('Lacuna::DB::Result::Map::Body')->find($planet_id);
    $page_number ||= 1;

    unless (defined $planet) {
        confess [1002, 'Could not locate that planet.'];
    }
    unless ($planet->isa('Lacuna::DB::Result::Map::Body::Planet')) {
        confess [1009, 'The Henge can only view incoming ships for nearby planets.'];
    }
    unless ($building->body->calculate_distance_to_target($planet) < $building->level * 1000) {
        confess [1009, 'That planet is too far away.'];
    }

    my @fleet;
    my $now = time;
    my $incoming_ships = return Lacuna->db->resultset('Lacuna::DB::Result::Ships')->search(
        {
            foreign_body_id => $planet->id,
            direction       => 'out',
            task            => 'Travelling',
        }
    );
    my $ships = $incoming_ships->search({}, {rows => 25, page => $page_number, join => 'body'});
    my $see_ship_type = ($building->level * 500) * ($building->efficiency / 100);
    my $see_ship_path = ($building->level * 600) * ($building->efficiency / 100);
    my @my_planets = $empire->planets->get_column('id')->all;
    while (my $ship = $ships->next) {
        if ($ship->date_available->epoch <= $now) {
            $ship->body->tick;
        }
        else {
            my %ship_info = (
                id              => $ship->id,
                name            => 'Unknown',
                type_human      => 'Unknown',
                type            => 'unknown',
                date_arrives    => $ship->date_available_formatted,
                from            => {},
            );
            if ($ship->body_id ~~ \@my_planets || $see_ship_path >= $ship->stealth) {
                $ship_info{from} = {
                    id      => $ship->body->id,
                    name    => $ship->body->name,
                    empire  => {
                        id      => $ship->body->empire->id,
                        name    => $ship->body->empire->name,
                    },
                };
                if ($ship->body_id ~~ \@my_planets || $see_ship_type >= $ship->stealth) {
                    $ship_info{name} = $ship->name;
                    $ship_info{type} = $ship->type;
                    $ship_info{type_human} = $ship->type_formatted;
                }
            }
            push @fleet, \%ship_info;
        }
    }
    return {
        status                      => $self->format_status($empire, $building->body),
        number_of_ships             => $ships->pager->total_entries,
        ships                       => \@fleet,
    };
}

sub view_planet_orbiting {
    my ($self, $session_id, $building_id, $planet_id, $page_number) = @_;
    my $empire = $self->get_empire_by_session($session_id);
    my $building = $self->get_building($empire, $building_id);
    my $planet = Lacuna->db->resultset('Lacuna::DB::Result::Map::Body')->find($planet_id);
    $page_number ||= 1;

    unless (defined $planet) {
        confess [1002, 'Could not locate that planet.'];
    }
    unless ($planet->isa('Lacuna::DB::Result::Map::Body::Planet')) {
        confess [1009, 'The Henge can only view orbiting ships for nearby planets.'];
    }
    unless ($building->body->calculate_distance_to_target($planet) < $building->level * 1000) {
        confess [1009, 'That planet is too far away.'];
    }

    my @fleet;
    my $now = time;
    my $orbiting_ships = Lacuna->db->resultset('Lacuna::DB::Result::Ships')->search(
        {
            foreign_body_id => $planet->id,
            task            => { in => ['Defend','Orbiting'] },
        }
    );
    my $ships = $orbiting_ships->search({}, {rows => 25, page => $page_number, join => 'body'});
    my $see_ship_type = ($building->level * 500) * ($building->efficiency / 100);
    my $see_ship_path = ($building->level * 600) * ($building->efficiency / 100);
    my @my_planets = $empire->planets->get_column('id')->all;
    while (my $ship = $ships->next) {
        if ($ship->date_available->epoch <= $now) {
            $ship->body->tick;
        }
        my %ship_info = (
            id              => $ship->id,
            name            => 'Unknown',
            type_human      => 'Unknown',
            type            => 'unknown',
            date_arrived    => $ship->date_available_formatted,
            from            => {},
        );
        if ($ship->body_id ~~ \@my_planets || $see_ship_path >= $ship->stealth) {
            $ship_info{from} = {
                id      => $ship->body->id,
                name    => $ship->body->name,
                empire  => {
                    id      => $ship->body->empire->id,
                    name    => $ship->body->empire->name,
                },
            };
            if ($ship->body_id ~~ \@my_planets || $see_ship_type >= $ship->stealth) {
                $ship_info{name} = $ship->name;
                $ship_info{type} = $ship->type;
                $ship_info{type_human} = $ship->type_formatted;
            }
        }
        push @fleet, \%ship_info;
    }
    return {
        status                      => $self->format_status($empire, $building->body),
        number_of_ships             => $ships->pager->total_entries,
        ships                       => \@fleet,
    };
}

sub list_planets {
    my ($self, $session_id, $building_id, $star_id) = @_;
    my $empire = $self->get_empire_by_session($session_id);
    my $building = $self->get_building($empire, $building_id);
    my $star;
    if ($star_id) {
        $star = Lacuna->db->resultset('Lacuna::DB::Result::Map::Star')->find($star_id);
        unless (defined $star) {
            confess [1002, 'Could not find that star.'];
        }
    }
    else {
        $star = $building->body->star;
    }
    unless ($building->body->calculate_distance_to_target($star) < $building->level * 1000) {
        confess [1009, 'That star is too far away.'];
    }
    my @planets;
    my $bodies = $star->bodies;
    while (my $body = $bodies->next) {
        next unless $body->isa('Lacuna::DB::Result::Map::Body::Planet');
        push @planets, {
            id      => $body->id,
            name    => $body->name,
        };
    }

    return {
        status  => $self->format_status($empire, $building->body),
        planets => \@planets,
    };
}

__PACKAGE__->register_rpc_method_names(qw(view_planet_incoming view_planet_orbiting list_planets));

no Moose;
__PACKAGE__->meta->make_immutable;
