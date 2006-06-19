package cPanel::SyncUtil;

use strict;
use warnings;
use Carp;
use File::Spec;

use File::Slurp;
use Digest::MD5::File;

use version; our $VERSION = qv('0.0.2');

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    _read_dir        _write_file
    _raw_dir         _chown_pwd_recursively 
    _get_opts_hash   _sync_touchlock_pwd 
    _safe_cpsync_dir _unlock
    _lock
);
our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK );

sub _read_dir   { goto &read_dir;   }

sub _write_file { goto &write_file; }

sub _lock {
    for(@_) {
        next if !-d $_;
        _write_file(File::Spec->catfile($_, '.cpanelsync.lock'), 'locked');
    }
}

sub _unlock {
    for(@_) {
        next if !-d $_;
        _write_file(File::Spec->catfile($_, '.cpanelsync.lock'), '');
    }
}

sub _safe_cpsync_dir {
    my ($dir) = @_;
    return 1 if defined $dir
                && $dir !~ /\.bak/
                && $dir !~ /^\./
                && -d $dir
                && !-l $dir
                ;
    return 0;
}

sub _chown_pwd_recursively {
    my ( $user, $group ) = @_;

    my $chown = defined $group ? "$user:$group" : $user;
    croak 'User [and group] must be ^\w+$' if $chown !~ m{^\w+(\:\w+)?$};

    system 'chown', '-R', $chown, '.';
}

sub _raw_dir {
    require Archive::Tar;
    require Cwd;
    my ( $base, $archive, $verbose, @files ) = @_;
    my $bz2_opt = $verbose ? '-kv' : '-k';
    my $pwd = Cwd::cwd();
    chdir $base or return;
    if(!-d $archive) {
        $! = 20;
        return;
    }
    if($archive ne '.') {
        my $tar = Archive::Tar->new();
        for my $file ( _read_dir($archive) ) {
            next if $file !~ m{\.bz2\.bz2$} || $file =~ m{\.bz2$};
            $tar->add_files("$archive/$file");
        }
        $tar->write("$archive.tar");

        system 'bzip2', $bz2_opt, "$archive.tar";
    }
    if (@files) {
        chdir $archive or return;
        for my $file (@files) {
            system 'bzip2', $bz2_opt, $file if -f $file;
        }
        cPanel::SyncUtil::_sync_touchlock_pwd();
    }
    else {
        chdir "$archive" or return;
        cPanel::SyncUtil::_sync_touchlock_pwd();
    }

    chdir $pwd or return;

    1;
}

sub _get_opts_hash {
    require Getopt::Std;
    my ( $args, $opts_ref ) = @_;

    $opts_ref = {} if ref $opts_ref ne 'HASH';
    Getopt::Std::getopts( $args, $opts_ref );

    return wantarray ? %{$opts_ref} : $opts_ref;
}

sub _sync_touchlock_pwd {
    $|++;
    require Cwd;
    my $cwd = Cwd::getcwd();

    print "$0 [$> $< : $cwd] Building .cpanelsync file...";

    my @files = split( /\n/, `find .` );

    my %oldmd5s;
    if ( -e '.cpanelsync' ) {
        open my $cps_fh, '<', '.cpanelsync' or die "$cwd/.cpanelsync read failed: $!";
        while (<$cps_fh>) {
            chomp;
            my ( $ftype, $rfile, $perm, $extra ) = split( /===/, $_ );
            $oldmd5s{$rfile} = $extra if $ftype eq 'f';
        }
        close $cps_fh;
    }

    open my $cpsw_fh, '>', '.cpanelsync' or die "$cwd/.cpanelsync write failed: $!";

    FILE:
    foreach my $file (@files) {
        next FILE if $file =~ /===/
                     || $file =~ /\.cpanelsync/
                     || $file =~ /\.cpanelsync.lock/;

        my $tfile;

        if ( $file =~ /\.bz2$/ ) {
            $tfile = $file;
            $tfile =~ s/\.bz2$//g;
            next FILE if -e $file && -e $tfile;
        }

        my $perms = substr( sprintf( '%o', ( stat($file) )[2] ), -3, 3 );

        if ( $cwd =~ /\/bin$/ && ( $file eq './cpwrap' || $file eq './jailshell' ) ) {
            $perms = 4755;
        }

        if ( -l $file ) {
            my $point = readlink($file);
            print {$cpsw_fh} "l===$file===$perms===$point\n";
        }
        elsif ( -d $file ) {
            print {$cpsw_fh} "d===$file===$perms\n";
        }
        else {
            print "Warning: zero sized file $file.bz2\n" if -z "$file.bz2";

            my $md5sum = Digest::MD5::File::file_md5_hex($file);

            system( 'bzip2', '-kfv', $file )
                if (exists $oldmd5s{$file} && $md5sum ne $oldmd5s{$file})
                   || !-e "$file.bz2"
                   || -z "$file.bz2";
            print {$cpsw_fh} "f===$file===$perms===$md5sum\n";
        }
    }
    print {$cpsw_fh} ".\n";
    close $cpsw_fh;

    system qw(bzip2 -fk .cpanelsync);

    print "Done\n";

    system qw(touch .cpanelsync.lock);

    return 1; # make more robust
}

1;

__END__

=head1 NAME

cPanel::SyncUtil - Perl extension for creating utilities that work with cpanelsync aware directories

=head1 SYNOPSIS

  use cPanel::SyncUtil;

=head1 DESCRIPTION

These utility functions can be used to in scripts that create and work with cpanelsync environments. 

=head1 EXAMPLE

See scripts/cpanelsync_build for a working example that can be used to build cPanel's cPAddon Vendor cpanelsync directory for your website.

=head1 EXPORT

None by default, all functions are exportable if you wish:

    use cPanel::SyncUtil qw(_raw_dir);
    
    use cPanel::SyncUtil qw(:all);

=head1 FUNCTIONS

=head2 _chown_pwd_recursively

Takes as its first argument a user that matches ^\w+$ (and optionally a group as its second argument, also matching ^\w+$)
and recursively chown's the current working directory to the given user (and group if given).

Currently the return value is from a system() call to chown.

=head2 _safe_cpsync_dir

Returns true if the given argument is a directory that it is safe to be cpanelsync'ified.

See the simple, scripts/cpanelsync_build_dir script for example useage while recursing directories.

=head2 _raw_dir


This function makes the .tar and .bz2 version of the file system.

Its arguments are the following:

   _raw_dir($base, $archive, $verbose, @files);

$base and $archive are the only required arguments.

$archive is a directory in $base.

It will chdir in $base and the process the directory $archive

If $verbose is true, output will be verbose.

If @files is specified each item in it is also processed.

Each item in @files must be a file (-f) in $base/$archive.

If it returns false the error is in $!

    _raw_dir($base, $archive, $verbose, @files) 
        or die "_raw_dir($base, $archive, $verbose, @files) failed: $!";

Its very important to check the return value because if its failed its possible you will not be in the directory you think and then subsequent file operations will either fail or not work like you expect. Plus if its returned false then there is either a file system problem or the input to the function is not valid. In other words, if it fails you need to resolve the problem before continuing so die()ing is a good idea generally.

_sync_touchlock_pwd is then run on $base/$archive so that its now a cpanelsync directory

=head2 _get_opts_hash 

Shortcut to get a hash (in array context) or hash ref (in scalar context) of the script using this module's command line options.

Takes the same exact input as L<Getopt::Std> getopts()

=head2 _sync_touchlock_pwd

Creates the .cpanelsync file (and its .bz2 version) and .cpanelsync.lock for the current working directory

=head2 _read_dir

Shortcut to L<File::Slurp>'s read_dir

=head2 _write_file

Shortcut to L<File::Slurp>'s write_file

=head2 _lock

Locks the given directories.

    _lock(qw(foo bar baz));

=head2 _unlock

Unlocks the given directories.

    _unlock(qw(foo bar baz));

=head1 SEE ALSO

L<cPanel>, L<http://www.cpanel.net>

=head1 TODO

replace system() calls with perl versions.

anything mentioned in the source

=head1 AUTHOR

Daniel Muey, L<http://drmuey.com/cpan_contact.pl> 

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 cPanel, Inc.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
