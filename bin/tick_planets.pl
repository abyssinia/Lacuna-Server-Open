use 5.010;
use strict;
use lib '/data/Lacuna-Server/lib';
use Lacuna::DB;
use Lacuna;
use Lacuna::Util qw(randint format_date to_seconds);
use Getopt::Long;
$|=1;
our $quiet;
GetOptions(
    'quiet'         => \$quiet,  
);


out('Started');
my $start = DateTime->now;

out('Loading DB');
our $db = Lacuna->db;

out('Ticking planets');
my $planets = $db->resultset('Lacuna::DB::Result::Map::Body')->search({ empire_id   => {'>' => 0} });
while (my $planet = $planets->next) {
    out('Ticking '.$planet->name);
    $planet->tick;
}

my $finish = DateTime->now;
out('Finished');
out((to_seconds($finish - $start)/60)." minutes have elapsed");


###############
## SUBROUTINES
###############

sub out {
    my $message = shift;
    unless ($quiet) {
        say format_date(DateTime->now), " ", $message;
    }
}

