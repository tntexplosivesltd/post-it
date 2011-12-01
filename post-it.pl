#!/usr/bin/env perl
# See LICENCE for licence details
# Or go to http://files.entropy.net.nz/LICENCE

#######################################
#######################################
#                                     #
# TODO: add removing                  #
# TODO: command line arguments        #
# TODO: config file                   #
# TODO: add method for commands       #
# TODO: commands can be done by PM    #
# s/$line//;                          #
#                                     #
#######################################
#######################################


use warnings;
use strict;
use POE;
use POE::Component::IRC;
use utils;

my ($server, $port, $ownernick, $irc, $nickname, %config, %todo);

sub command
{
  my ($todo_ref, $irc, %info) = @_;
  for (keys %info)
  {
    print "$_: $info{$_}\n";
  }
  my $command = $info{'command'};

  # 
  if ($command =~ /^!todo/)
  {
    # todo list
    if ($command =~ /^!todo( list)* *(\d+)*$/)
    {
      if ($2)
      {
        # specific line
      }
      else
      {
        # all lines
        return if not $todo_ref->{$info{'ident'}};
        for (my $i = 0; $i < @{$todo_ref->{$info{'ident'}}}; $i++)
        {
          print "Before\n";
          $$irc->yield('privmsg', $info{'nick'}, "$i: ${$todo_ref->{$info{'ident'}}}[$i]");
          print "After\n";
          print "$$irc->yield('privmsg', $info{'nick'}, \"$i: ${$todo_ref->{$info{'ident'}}}[$i]\")\n";
        }
      }
    }
    elsif ($command =~ /^!todo add (.+)$/)
    {
      $todo_ref->{$info{'ident'}} = [] if not ($todo_ref->{$info{'ident'}});
      push($todo_ref->{$info{'ident'}}, $1);
      $$irc->yield('privmsg', $info{'channel'}, "Added!");
    }
  }
}


# Create the component that will represent an IRC network.
$irc = POE::Component::IRC->spawn();
$nickname = "post-it";

# Create the bot session.  The new() call specifies the events the bot
# knows about and the functions that will handle those events.
POE::Session->create(
  inline_states => {
    _start     		    => \&bot_start,
    irc_001    		    => \&on_connect,
    irc_disconnected 	=> \&on_disconnect,
    irc_socketerr 	  => \&on_socket_error,
    irc_public 		    => \&on_public,
    irc_msg		        => \&on_msg,
  },
);

$poe_kernel->run();


# The bot session has started.  Register this bot with the "magnet"
# IRC component.  Select a nickname.  Connect to a server.
sub bot_start {
  %config = utils::parse_config("./settings.conf");
  # validation
  $config{'nick'} = "post_it" if not $config{'nick'};
  $config{'username'} = "post_it" if not $config{'username'};
  $config{'ircname'} = "post_it" if not $config{'ircname'};
  $config{'server'} = "irc.segfault.net.nz" if not $config{'server'};
  $config{'port'} = "6668" if not $config{'port'};
  $config{'channel'} = "#bots" if not $config{'channel'};
  print "Connecting...\n";
  $irc->yield(register => "all");
  $irc->yield(
    connect => {
      Nick      => $config{'nick'},
      Username  => $config{'username'},
      Ircname   => $config{'ircname'},
      Server    => $config{'server'},
      Port      => $config{'port'},
    }
  );
}

# The bot has successfully connected to a server. Wait for joining instructions
sub on_connect {
  print "Successfully connected.\n";
  print "Connecting to $config{'channel'}\n";
  $irc->yield(join => $config{'channel'});
  $todo{'lol'} = "haha";
}

sub on_disconnect {
  print "Disconnected from server\n";
  exit 0;
}

sub on_socket_error {
  my $error = $_[ARG0];
  print "Error connecting to server: $error\n";
  exit 0;
}

# actual communication stuff

# The bot has received a public message. Print and log it
sub on_public {
  my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
  if ($msg =~ /^!/)
  {
    print join(":", split(/!/, $who))."\n";
    my @user = (split(/!/, $who));
    my $channel = $where->[0];
    my %info_to_pass = ('nick' => $user[0], 'ident' => $user[1], 'channel' => $channel, 'command' => $msg);
    command(\%todo, \$irc, %info_to_pass);
  }
}

# The bot has recieved a private message. Parse it for commands
sub on_msg {
  my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
  print join(":", split(/!/, $who))."\n";
  my @user = (split(/!/, $who));
  my $channel = $where->[0];
  my %info_to_pass = ('nick' => $user[0], 'ident' => $user[1], 'channel' => $channel, 'command' => $msg);
  command(\%todo, \$irc, %info_to_pass);
}

exit 0;
