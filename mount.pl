#!/usr/bin/perl

# Copyright 2011 Dave Jacoby <http://pm.purdue.org/jacoby/>

# This program is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.

# script to mount via FUSE various file systems
# now, mount-all doesn't mean *all* and that's a good thing.

# 2011/11 - DAJ - Added -o workaround=rename to allow GIT over
# sshfs

use 5.010 ;
use strict ;
use warnings ;
use Carp ;
use Getopt::Long ;
use IO::Interactive qw{ interactive } ;
use subs qw( mount unmount ) ;

# Definition
# mount.pl                   --   mounts all in the config
# mount.pl -Q                -- unmounts all in the config
# mount.pl -m foo            --   mounts foo, if foo is in config
# mount.pl -u foo            -- unmounts foo, if foo is in config
# mount.pl -m foo -u bar     --   mounts and unmounts can be mixed

my %flag ;
my %local ;
my @mount ;
my %mountprog ;
my %protocol ;
my %remote ;
my @unmount ;
my $unmount ;
my $verbose ;

$mountprog{sshfs}   = '/usr/bin/sshfs' ;
my $unmountprog = '/bin/fusermount' ;

GetOptions( 'mount=s'   => \@mount,
            'unmount=s' => \@unmount,
            'quit'      => \$unmount,
            'verbose'   => \$verbose,
             ) ;


# don't like the full hardcode
open DATA , '<' , '/home/jacoby/.mount.conf' or croak $! ;
while ( <DATA> ) {
    chomp ;
    my $line = $_ ;
    next if $line !~ m{\w}mx ;
    my $result = ( split m{\#}mx, $line )[ 0 ] ;
    $line = $result ;
    next if $line !~ m{\w}mx ;
    my ( $name, $flag , $protocol , $remote, $local ) = split m{\s*\|\s*}mx, $line ;
    $name =~ s{\s}{}g ;
    $local{ $name }  = $local ;
    $remote{ $name } = $remote ;
    $protocol{ $name }  = $protocol ;
    $flag{ $name } = length $flag ;
    }


# UNMOUNT EVERYTHING
if ( $unmount ) {
    for my $mount ( sort { lc $a cmp lc $b } keys %local ) {
        unmount $mount , $local{ $mount } ;
        }
    }

# MOUNT EVERYTHING
elsif ( ( $#mount == -1 ) && ( $#unmount == -1 ) ) {
    for my $mount ( sort { lc $a cmp lc $b } keys %local ) {
        next unless $flag{ $mount } ;
        mount $mount , $remote{ $mount }, $local{ $mount } ;
        }
    }

# MIXED MOUNTS AND UNMOUNTS
else {
    # mounts first
    for my $mount ( @mount ) {
        mount $mount , $remote{ $mount }, $local{ $mount } ;
        }

    # then unmounts
    for my $mount ( @unmount ) {
        unmount $mount , $local{ $mount } ;
        }
    }

exit 0 ;

sub mount {
    my $name   = shift ;
    my $remote = shift ;
    my $local  = shift ;
    $verbose and say { interactive } $name ;
    $verbose and say { interactive } $remote ;
    $verbose and say { interactive } $local ;

    return 0 if $name !~ /\w/mx ;   $verbose and say { interactive } 'Pass' ;
    return 0 if $remote !~ /\w/mx ; $verbose and say { interactive } 'Pass' ;
    return 0 if $local !~ /\w/mx ;  $verbose and say { interactive } 'Pass' ;
    return 0 if !-d $local ;        $verbose and say { interactive } 'Pass' ;
    #should mkdir $local here
    say 'Mounting ' . $name ;
    print qx( /usr/bin/sshfs -o workaround=rename $remote $local ) ;
    return 1 ;
    }

sub unmount {
    my $name  = shift ;
    my $local = shift ;
    return 0 if $name !~ /\w/mx ;  $verbose and say { interactive } 'Pass' ;
    return 0 if $local !~ /\w/mx ; $verbose and say { interactive } 'Pass' ;
    return 0 if !-d $local ;       $verbose and say { interactive } 'Pass' ;
    say 'Unmounting ' . $name ;
    say qx( /bin/fusermount -u $local ) ;
    return 1 ;
    }
