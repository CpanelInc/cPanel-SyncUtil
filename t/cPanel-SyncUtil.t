use strict;
use warnings;

use File::Spec;

use Test::More tests => 20;
BEGIN { use_ok('cPanel::SyncUtil', ':all') };

#### setup test environment ##
BEGIN { our $testdir = 'cpanelsync_test_files'; };

# attempt to do tests in t/ directory
my $upt = File::Spec->catdir( File::Spec->updir(), 't');
chdir $upt if -d $upt;
chdir 't' if -d 't';

my $testdir = 'cpanelsync_test_files';

# clean up if last time had left overs
_t_cleanup();

# need it fresh so it shouldn't exist so we die:
mkdir $testdir or die "Could not mkdir $testdir: $!";

# make a bunch of files and directories in $testdir

#### run some tests ##
# run some functions and test (increment Test::More's tests) 
# that the expected new files exist

my $file = File::Spec->catfile($testdir, 'filea');
# _write_file
ok( _write_file( $file, 'filea content' ), '_write_file function call');
ok( -e $file, '_write_file file exists' );

chdir $testdir or die "Can't move into test dir: $!";

mkdir 'archive_only' or die "Can't create 'only' dir: $!";
chdir 'archive_only' or die "Can't go into 'only' dir: $!";
_write_file( $_, "$_ content") for qw( filea fileb );
mkdir 'dira' or die "Can't create a test directory in 'only': $!";
_write_file( $_, "$_ content") for qw( filec filed );
chdir '..' or die "Can not go back down to run more tests: $!";

mkdir 'archive_plus' or die "Can't create 'plus' dir: $!";
chdir 'archive_plus' or die "Can't go into 'plus' dir: $!";
_write_file( $_, "$_ content") for qw( filea fileb );
mkdir 'dira' or die "Can't create a test directory in 'plus': $!";
_write_file( $_, "$_ content") for qw( filec filed );
chdir '..' or die "Can not go back down to run more tests: $!";

# _read_dir
ok( my @files = _read_dir('.'), '_read_dir function call' );
ok( @files == 3, '_read_dir results' );

# _sync_touchlock_pwd
diag('Running _sync_touchlock_pwd()');
ok( _sync_touchlock_pwd(), '_sync_touchlock_pwd function call' );
for(qw( .cpanelsync .cpanelsync.bz2 .cpanelsync.lock filea.bz2 )) {
    ok( -e $_, "_sync_touchlock_pwd $_" );
}

# _raw_dir
chdir '..' or die "Can not go back down to run more tests: $!";
my @ftodo = qw(filea fileb dira);

ok( _raw_dir($testdir, 'archive_only', 0), '_raw_dir no @files' );
my $tara = File::Spec->catfile($testdir, 'archive_only.tar');
ok( -e $tara, "$tara created");
ok( -e "$tara.bz2", "$tara.bz2 created" );

ok( _raw_dir($testdir, 'archive_plus', 0, @ftodo), '_raw_dir w/ @files' );
my $tarb = File::Spec->catfile($testdir, 'archive_plus.tar');
ok( -e $tarb, "$tarb created");
ok( -e "$tarb.bz2", "$tarb.bz2 created" );
for(@ftodo) {
    my $path = File::Spec->catfile($testdir, 'archive_plus', $_);
    ok( -e $path, '@files bz2 of: ' . $path);
}

ok( !_raw_dir($testdir, 'filea', 0), '_raw_dir non-dir $archive fails ok' );

#### clean up our mess ##

END { _t_cleanup(); }

sub _t_cleanup {
    # if /bin/rm is an executable, execute it
    system('/bin/rm', '-rf', $testdir) if -x '/bin/rm';

    # check for a module or two that can clean it up without system

    # if it failed or didn't exist, remind them to clean up
    print "Its safe to remove $testdir now." if -d $testdir;
}
