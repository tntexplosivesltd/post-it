#######################################
#######################################
#                                     #
# TODO: add removing and number limit #
# s/$line//;                          #
#                                     #
#######################################
#######################################

#!/usr/bin/perl

use warnings;
use strict;
use POE;
use POE::Component::IRC;
sub CHANNEL () { }

# Create the component that will represent an IRC network.
my ($irc) = POE::Component::IRC->spawn();

my $nickname = "pBOA";
# The owner of the bot (me)
my $ownernick = "thomas";
my $password = "would you kindly";

# logging flag
my $log = 1;

my ($gsec,$gmin,$ghour,$gmday,$gmon,$gyear,$gwday,$gyday,$gisdst) = localtime(time);
my $fdate = sprintf("%04s-%02s-%02s", ($gyear + 1900), ($gmon + 1), $gmday);

# Create the bot session.  The new() call specifies the events the bot
# knows about and the functions that will handle those events.
POE::Session->create(
  inline_states => {
    _start     		=> \&bot_start,
    irc_001    		=> \&on_connect,
    irc_disconnected 	=> \&on_disconnect,
    irc_socketerr 	=> \&on_socket_error,
    irc_join 		=> \&on_join,
    irc_part		=> \&on_part,
    irc_public 		=> \&on_public,
    irc_msg		=> \&on_msg,
    irc_ctcp_action	=> \&on_me,
  },
);

$poe_kernel->run();


# The bot session has started.  Register this bot with the "magnet"
# IRC component.  Select a nickname.  Connect to a server.
sub bot_start {
  print "pBOA - perl Bot Of Awesomeness\n";
  print "Connecting...\n";
  $irc->yield(register => "all");
  $irc->yield(
    connect => {
      Nick     => $nickname,
      Username => 'pBOA',
      Ircname  => 'Perl Bot Of Awesomeness',
      Server   => 'irc.segfault.net.nz',
      Port     => '6668',
    }
  );
}

# The bot has successfully connected to a server. Wait for joining instructions
sub on_connect {
  print "Successfully connected.\n";
}

sub on_disconnect {
  print "Disconnected from server\n";
  close(OUTPUT);
  close(CMDLOG);
  exit 0;
}

sub on_socket_error {
  my $error = $_[ARG0];
  print "Error connecting to server: $error\n";
  close(OUTPUT);
  close(CMDLOG);
  exit 0;
}


# actual communication stuff
sub on_join {
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  my $timestamp = sprintf("%02s:%02s:%02s", $hour, $min, $sec);
  my $nick = (split /!/, $_[ARG0])[0];
  my $channel = $_[ARG1];
  my $entry = "[$timestamp] $nick has joined $channel\n";
  &add_to_log($entry, $channel)
}

sub on_part {
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  my $timestamp = sprintf("%02s:%02s:%02s", $hour, $min, $sec);
  my $nick = (split /!/, $_[ARG0])[0];
  my $channel = $_[ARG1];
  my $entry = "[$timestamp] $nick has left $channel\n";
  &add_to_log($entry, $channel)
}

# The bot has received a public message. Print and log it
sub on_public {
  my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
  my $nick    = (split /!/, $who)[0];
  my $channel = $where->[0];
  if ($msg =~ /^!todo add ([\W\w]+)/i) {
    open(TODO, ">>$nick.todo") || warn "Could not open todo file for writing: $!\n";
    print TODO "$1\n";
    print "Added $1 to $nick\'s todo list\n";
    $irc->yield( privmsg => $channel => "Added!\n" );
    close(TODO);
  }
  elsif (($msg =~ /^!todo list/i) || ($msg =~ /!todo *$/)) {
    if ((-z "$nick.todo") || !(-e "$nick.todo")){
      print "No todo list exists for $nick\n";
      $irc->yield( privmsg => $channel => "No todo list exists for $nick\n" );
    }
    else {
      open(TODO, "<$nick.todo") || warn "Could not open todo file for reading: $!\n";
      while(<TODO>) {
        my $line = $_;
        print "$nick: $line\n";
        $irc->yield( privmsg => $channel => "$nick: $line\n" );
      }
      close(TODO);
    }
  }
  else {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    my $timestamp = sprintf("%02s:%02s:%02s", $hour, $min, $sec);
    my $entry = "[$timestamp] <$nick:$channel> $msg\n";
    &add_to_log($entry, $channel)
  }
}

# The bot has recieved a private message. Parse it for commands
sub on_msg {
  open(CMDLOG, ">>command_log.txt") || warn "Could not open command log file: $!\n";
  my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
  my $nick = (split /!/, $_[ARG0])[0];
  my $channel = $where->[0];
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  my $timestamp = sprintf("%04s-%02s-%02s,%02s:%02s:%02s",($year + 1900), ($mon + 1), $mday, $hour, $min, $sec);

  if (($nick eq $ownernick) && ($msg =~ /$password/i)) {
    if (($msg =~/logging[_ ]*off/i) && ($log == 1))  {
      $log = 0;
      print "Logging will now be turned off. Flushing file buffer...\n";
      print CMDLOG "[$timestamp] Logging turned off\n";
      my $ofh = select OUTPUT;
      $| = 1;
      print OUTPUT "";
      $| = 0;
      select $ofh;
      $irc->yield( privmsg => $nick => "pBOA logging is now turned off\n" );
    }

    elsif (($msg =~/logging[_ ]*on/i) && ($log == 0)) {
      $log = 1;
      print "Logging will now be turned on\n";
      print CMDLOG "[$timestamp] Logging turned on\n";
      $irc->yield( privmsg => $nick => "pBOA logging is now turned on\n" );
    }

    elsif ($msg =~/join[_ ]*(\#\w+)/i) {
      print "Trying to join $1\n";
      print CMDLOG "[$timestamp] Joined $1\n";
      $irc->yield( privmsg => $nick => "pBOA is trying to join $1\n" );
      $irc->yield( join => $1 );
    }

    elsif ($msg =~/part[_ ]*(\#\w+)/i) {
      print "Trying to leave $1\n";
      print CMDLOG "[$timestamp] Left $1\n";
      $irc->yield( privmsg => $nick => "pBOA is trying to leave $1\n" );
      $irc->yield( part => $1 );
    }

    elsif (($msg =~/quit/i) || ($msg =~ /die/i)) {
      print "Leaving server\n";
      print CMDLOG "[$timestamp] Left server\n";
      $irc->yield( privmsg => $nick => "pBOA is leaving the server" );
      $irc->yield( quit => "pBOA has left the server" );
    }

    elsif ($msg =~/say "([\w\W][\w\W]*)" in (\#\w+)/i) {
      print "Saying \"$1\" in $2\n";
      print CMDLOG "[$timestamp] Saying \"$1\" in $2\n";
      $irc->yield( privmsg => $nick => "Saying \"$1\" in $2" );
      $irc->yield( privmsg => $2 =>"$1" );
    }
    else
    {
      print "Unrecognised command $msg\n";
      print CMDLOG "[$timestamp] Unrecognised command $msg\n";
      $irc->yield( privmsg => $nick => "Unrecognised command $msg\n" );
    }
  }
  else
  {
    print "$nick said $msg to me\n";
    print CMDLOG "[$timestamp] $nick said $msg to me\n";
    $irc->yield( privmsg => $nick => "Sorry, who are you?\n" );
  }
  close(CMDLOG); 
}

sub on_me {
  my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
  my $nick = (split /!/, $_[ARG0])[0];
  my $channel = $_[ARG1];
  my $action = $_[ARG2];
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  my $timestamp = sprintf("%02s:%02s:%02s", $hour, $min, $sec);
  my $entry = "[$timestamp]*  $nick $action\n";
  &add_to_log($entry, $channel)
}

sub add_to_log {
  my $to_add = $_[0];
  my $channel = $_[1];
  if ($log == 1) {
    open(OUTPUT, ">>$channel\_$fdate.txt") || warn "Could not open log file: $!\n";
    print OUTPUT "$to_add";
    close(OUTPUT);
  }
  print "$to_add";
}

close(OUTPUT);
close(CMDLOG);
exit 0;
