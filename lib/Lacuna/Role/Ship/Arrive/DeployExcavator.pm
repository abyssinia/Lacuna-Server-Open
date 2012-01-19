package Lacuna::Role::Ship::Arrive::DeployExcavator.pm

use strict;
use Moose::Role;

after handle_arrival_procedures => sub {
  my ($self) = @_;

  # we're coming home
  return if ($self->direction eq 'in');
    
  # do we have archaeology of level 15 or greater, if not, turn around
  my $body = $self->body;
  my $archaeology = $body->archaeology;
  return unless ((defined $archaeology) && ($archaeology->level >= 15));

  # can we deploy a excavator
  my $empire = $body->empire;
  my $foreign_body = $self->foreign_body;
  my $can = eval{$archaeology->can_add_excavator($foreign_body, 1)};
  my $reason = $@;

  # yes, we can
  if ($can && !$reason) {
    $archaeology->add_excavator($foreign_body)->update;
    $empire->send_predefined_message(
      tags        => ['Alert'],
      filename    => 'excavator_deployed.txt',
      params      => [$body->id, $body->name, $foreign_body->x, $foreign_body->y, $foreign_body->name, $self->name],
    );
    $self->delete;
#        my $type = ref $foreign_body;
#        $type =~ s/^.*::(\w\d+)$/$1/;
#        $empire->add_medal($type);
        confess [-1];
  }
  # no we can't
  else {
    my $message = (ref $reason eq 'ARRAY') ? $reason->[1] : 'We have encountered a glitch.';
    $empire->send_predefined_message(
      tags        => ['Alert'],
      filename    => 'cannot_deploy_excavator.txt',
      params      => [$message, $foreign_body->x, $foreign_body->y, $foreign_body->name, $body->id, $body->name, $self->name],
    );
  }
};

after can_send_to_target => sub {
    my ($self, $target) = @_;
    my $archaeology = $self->body->archaeology;
    confess [1013, 'Cannot control excavators without an Archaeology.'] unless (defined $archaeology);
    confess [1013, 'Your Archaeology Ministry must be level 15 or higher in order to send excavators.'] unless ($archaeology->level >= 15);
    $archaeology->can_add_excavator($target);
# Will need to make this only pertaining to excavation later.
    if ($target->star->station_id) {
        if ($target->star->station->laws->search({type => 'MembersOnlyMiningRights'})->count) {
            unless ($target->star->station->alliance_id == $self->body->empire->alliance_id) {
                confess [1010, 'Only '.$target->star->station->alliance->name.' members can excavate asteroids in the jurisdiction of the space station.'];
            }
        }
    }
};

1;
