#!/usr/bin/perl

# Copyright 2012 Dave Jacoby <http://pm.purdue.org/jacoby/>

# This program is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.

# script to mount via FUSE various file systems
# now, mount-all doesn't mean *all* and that's a good thing.

# 2011/11 - DAJ - Added -o workaround=rename to allow GIT over
# sshfs
# 2012/02 - DAJ - Added groups for mounting and dismounting
# 2012/08 - Lev Gorenstein <lev@ledorub.poxod.com> - un-hardcoded
# configuration file name and location, added '-c config' option.
# 2012/08 - DAJ - added naive help function. Need to re-do as POD,
# 2012/08 - @petdance - simplified mount_help

use 5.010 ;
use strict ;
use warnings ;
use Carp ;
use Data::Dumper ;
use Getopt::Long ;
use IO::Interactive qw{ interactive } ;
use subs qw( mount unmount ) ;

# Definition
# mount.pl                   --   mounts all in the config
# mount.pl -c /alt/conf/ig   --   mounts all in the alternative config
# mount.pl -Q                -- unmounts all in the config
# mount.pl -m foo            --   mounts foo, if foo is in config
# mount.pl -u foo            -- unmounts foo, if foo is in config
# mount.pl -m foo -u bar     --   mounts and unmounts can be mixed

my %flag ;
my %local ;
my @mount ;
my %mountprog ;
my %protocol ;
my $help = 0 ;
my $groups ;
my %remote ;
my @unmount ;
my $unmount ;
my $verbose ;
my @group_mount ;
my @group_unmount ;
my $config = $ENV{'HOME'} . "/.mount.conf" ;

$mountprog{ sshfs } = '/usr/bin/sshfs' ;
my $unmountprog = '/bin/fusermount' ;

GetOptions(
    'mount=s'    => \@mount,
    'unmount=s'  => \@unmount,
    'group=s'    => \@group_mount,
    'dismount=s' => \@group_unmount,
    'quit'       => \$unmount,
    'verbose'    => \$verbose,
    'config=s'   => \$config,
    'help'       => \$help,
    ) ;

if ( $help || ! -f $config ) {
    mount_help() ;
    exit ;
    }

# don't like the full hardcode
# open my $DATA, '<', '/home/jacoby/.mount.conf' or croak $! ;
open my $DATA, '<', $config or croak $! ;
while ( <$DATA> ) {
    chomp ;
    my $line = $_ ;
    next if $line !~ m{\w}mx ;
    my $result = ( split m{\#}mx, $line )[ 0 ] ;
    $line = $result ;
    next if $line !~ m{\w}mx ;
    my ( $name, $group, $flag, $protocol, $remote, $local ) = split m{\s*\|\s*}mx, $line ;
    $name =~ s{\s}{}g ;
    push @{ $groups->{ $group } }, $name ;

    $local{ $name }    = $local ;
    $remote{ $name }   = $remote ;
    $protocol{ $name } = $protocol ;
    $flag{ $name }     = length $flag ;
    }
close $DATA ;

# instead of trying to deal with groups, put group members into
# the mount and unmount arrays
for my $group ( @group_mount ) {
    for my $machine ( @{ $groups->{ $group } } ) {
        push @mount, $machine ;
        }
    }
for my $group ( @group_unmount ) {
    for my $machine ( @{ $groups->{ $group } } ) {
        push @unmount, $machine ;
        }
    }

# UNMOUNT EVERYTHING
if ( $unmount ) {
    for my $mount ( sort { lc $a cmp lc $b } keys %local ) {
        unmount $mount , $local{ $mount } ;
        }
    }

# MOUNT EVERYTHING
elsif (( $#mount == -1 )
    && ( $#unmount == -1 )
    && ( $#group_mount == -1 )
    && ( $#group_unmount == -1 ) ) {
    for my $mount ( sort { lc $a cmp lc $b } keys %local ) {
        next unless $flag{ $mount } ;
        mount $mount , $remote{ $mount }, $local{ $mount } ;
        }
    }

# MIXED MOUNTS AND UNMOUNTS
else {

    # groups then individuals
    # unmounts first
    for my $group ( @group_unmount ) {
        for my $mount ( @{ $groups->{ $group } } ) {
            unmount $mount , $local{ $mount } ;
            }
        }

    for my $mount ( @unmount ) {
        unmount $mount , $local{ $mount } ;
        }

    # then mounts
    for my $group ( @group_unmount ) {
        for my $mount ( @{ $groups->{ $group } } ) {
            next unless $flag{ $mount } ;
            mount $mount , $remote{ $mount }, $local{ $mount } ;
            }
        }

    for my $mount ( @mount ) {
        mount $mount , $remote{ $mount }, $local{ $mount } ;
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

    return 0 if $name !~ /\w/mx ;
    $verbose and say { interactive } 'Pass' ;
    return 0 if $remote !~ /\w/mx ;
    $verbose and say { interactive } 'Pass' ;
    return 0 if $local !~ /\w/mx ;
    $verbose and say { interactive } 'Pass' ;
    return 0 if !-d $local ;
    $verbose and say { interactive } 'Pass' ;

    #should mkdir $local here
    say 'Mounting ' . $name ;
    print qx( /usr/bin/sshfs -o workaround=rename $remote $local ) ;
    return 1 ;
    }

sub unmount {
    my $name  = shift ;
    my $local = shift ;
    return 0 if $name !~ /\w/mx ;
    $verbose and say { interactive } 'Pass' ;
    return 0 if $local !~ /\w/mx ;
    $verbose and say { interactive } 'Pass' ;
    return 0 if !-d $local ;
    $verbose and say { interactive } 'Pass' ;
    say 'Unmounting ' . $name ;
    say qx( /bin/fusermount -u $local ) ;
    return 1 ;
    }

sub mount_help {
    say <DATA> ;
    }

#SHOULD REDO THIS AS POD

__DATA__

I created this program to handle via perl the increasingly large number of
SSHFS-mounted filesystems I was using. This program keeps track of the filesystems,
both remotely and local mountpoints, but not passwords.

Configuration is held in ~/.mount.conf, which looks like this :

### .mount.conf
# like many config files, hashes comment out

Machine1    |G|M|sshfs|machine1.long.url:   | /home/me/Machine1
Machine2    |G| |sshfs|machine2.long.url:   | /home/me/Machine2
#            ^ M indicates mounting via mount-all setting
Machine2Log |G|M|sshfs|machine2.long.url:/var/log | /home/me/Machine2log

The fields are:
    Name - the name of this mountpoint, for individual mounting and unmounting
    Group - the name of the group this mountpoint is in, to allow the mounting
            and unmounting of specific groups of file systems
    M    - indicates whether this gets mounted on mount-all
    Protocol - right now, only sshfs is supported
    Remote - follows the SSHFS syntax for remote mounts:
            network_address:/remote/file/system/if/any
    Local - where the mount point is on the local file system


Usage:
    mount.pl
        Mounts all
    mount.pl -Q
        Unmounts all
    mount.pl -g Foo -g Bar
        Mounts members of groups Foo and Bar
    mount.pl -d Foo -d Bar
        Unmounts members of groups Foo and Bar
    mount.pl -m Blee -m Quuz
        Mounts systems named Blee and Quuz
    mount.pl -u Blee -u Quuz
        Unounts systems named Blee and Quuz
    mount.pl -c /alt/conf/ig
        Uses alternate configuration file
