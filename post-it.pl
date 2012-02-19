#!/usr/bin/env perl
# See LICENCE for licence details
# Or go to http://files.entropy.net.nz/LICENCE

#######################################
#######################################
#                                     #
# TODO: add limit                     #
# TODO: command line arguments        #
# TODO: config file                   #
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

  # !todo....
  if ($command =~ /^!todo/)
  {
    if (not $todo_ref->{$info{'ident'}})
    {
      print "No to-do list in memory for $info{'ident'}, attempting to load\n";
      if (-e "$info{'ident'}\.todo")
      {
        # load todo list
        open(TODO, "<", "$info{'ident'}.todo") || warn "Couldn't open $info{'ident'}: $!\n";
        return if (tell(TODO) == -1);
        while(<TODO>)
        {
          push(@{$todo_ref->{$info{'ident'}}}, $_);
        }
        close(TODO);
        print "Loaded todo list for $info{'ident'}\n";
      }
      else
      {
        print "No list exists.\n";
        return;
      }
    }

    # todo list
    if ($command =~ /^!todo( list)* *(\d+)*$/)
    {
      if ($2)
      {
        if ($todo_ref->{$info{'ident'}})
        {
          my $index = $2;
          $index = 0 if $2 < 0;
          $index = (@{$todo_ref->{$info{'ident'}}} - 1) if $2 > @{$todo_ref->{$info{'ident'}}};
          $$irc->yield('privmsg', $info{'nick'}, "Item no. $index: ${$todo_ref->{$info{'ident'}}}[$index]");
        }
      }
      else
      {
        # all lines
        return if not $todo_ref->{$info{'ident'}};
        $$irc->yield('privmsg', $info{'nick'}, "$info{'nick'}'s to-do list:");
        for (my $i = 0; $i < @{$todo_ref->{$info{'ident'}}}; $i++)
        {
          if ($i > ($info{'limit'} - 1))
          {
            $$irc->yield('privmsg', $info{'nick'}, "---Limit reached.---");
            return;
          }
          $$irc->yield('privmsg', $info{'nick'}, "$i: ${$todo_ref->{$info{'ident'}}}[$i]");
        }
      }
    }
    # add to list
    elsif ($command =~ /^!todo add (.+)$/)
    {
      push(@{$todo_ref->{$info{'ident'}}}, $1) if ($todo_ref->{$info{'ident'}});
      open(TODO, ">>", "$info{'ident'}.todo") || warn "Could not open to-do list file: $!\n";
      return if (tell(TODO) == -1);
      print "Writing $1 to $info{'ident'}'s list\n";
      print TODO "$1\n";
      close(TODO);
      $$irc->yield('privmsg', $info{'channel'}, "Added!");
    }

    #todo remove
    elsif ($command =~ /^!todo remove (.+)$/)
    {
      my @removes;
      my @removes_indices;
      # find items to remove
      for (my $i = 0; $i < @{$todo_ref->{$info{'ident'}}}; $i++)
      {
        if (${$todo_ref->{$info{'ident'}}}[$i] =~ /$1/)
        {
          print "Will remove ${$todo_ref->{$info{'ident'}}}[$i]\n";
          push(@removes, ${$todo_ref->{$info{'ident'}}}[$i]);
          splice(@{$todo_ref->{$info{'ident'}}}, $i, 1);
          $i--;
        }
      }
      if (@removes)
      {
        open (TODO, ">", "$info{'ident'}.todo") || warn "Could not open to-to list file: $!\n";
        return if (tell(TODO) == -1);
        foreach my $entry (@{$todo_ref->{$info{'ident'}}})
        {
          print TODO "$entry";
          print "Writing $entry";
        }
        close(TODO);
        $$irc->yield('privmsg', $info{'nick'}, "Removed: ".join(", ", @removes));
      }
    }

    elsif ($command =~ /^!todo removepos (\d+)/)
    {
      return if not ($todo_ref->{$info{'ident'}});
      if ($1 > $#{$todo_ref->{$info{'ident'}}})
      {
        $$irc->yield('privmsg', $info{'channel'}, "Index $1 is larger than the last index of your todo list ($#{$todo_ref->{$info{'ident'}}}) items.");
        return;
      }
      else
      {
        my $removed = ${$todo_ref->{$info{'ident'}}}[$1];
        splice(@{$todo_ref->{$info{'ident'}}}, $1, 1);
        open (TODO, ">", "$info{'ident'}.todo") || warn "Could not open to-to list file: $!\n";
        return if (tell(TODO) == -1);
        foreach my $entry (@{$todo_ref->{$info{'ident'}}})
        {
          print TODO "$entry";
          print "Writing $entry";
        }
        close(TODO);
        $$irc->yield('privmsg', $info{'nick'}, "Removed: $removed");
      }
    }
  }
}


# Create the component that will represent an IRC network.
$irc = POE::Component::IRC->spawn();

# Create the bot session.  The new() call specifies the events the bot
# knows about and the functions that will handle those events.
POE::Session->create(
  inline_states => {
    _start            => \&bot_start,
    irc_001           => \&on_connect,
    irc_disconnected  => \&on_disconnect,
    irc_socketerr     => \&on_socket_error,
    irc_public        => \&on_public,
    irc_msg           => \&on_msg,
  },
);

$poe_kernel->run();


# The bot session has started.  Register this bot with the "magnet"
# IRC component.  Select a nickname.  Connect to a server.
sub bot_start
{
  %config = utils::parse_config("./settings.conf");
  # validation
  $config{'nick'} = "post-it" if not $config{'nick'};
  $config{'username'} = "post-it" if not $config{'username'};
  $config{'ircname'} = "post-it" if not $config{'ircname'};
  $config{'server'} = "irc.segfault.net.nz" if not $config{'server'};
  $config{'port'} = "6668" if not $config{'port'};
  $config{'channel'} = "#bots" if not $config{'channel'};
  $config{'limit'} = 5 if not $config{'limit'};
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
sub on_connect
{
  print "Successfully connected.\n";
  print "Connecting to $config{'channel'}\n";
  $irc->yield(join => $config{'channel'});
}

sub on_disconnect
{
  print "Disconnected from server\n";
  exit 0;
}

sub on_socket_error
{
  my $error = $_[ARG0];
  print "Error connecting to server: $error\n";
  exit 0;
}

# actual communication stuff

# The bot has received a public message. Print and log it
sub on_public
{
  my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
  if ($msg =~ /^!/)
  {
    my @user = (split(/!/, $who));
    my $channel = $where->[0];
    my %info_to_pass = ('nick' => $user[0], 'ident' => $user[1], 'channel' => $channel, 'command' => $msg, 'limit' => $config{'limit'});
    command(\%todo, \$irc, %info_to_pass);
  }
}

# The bot has recieved a private message. Parse it for commands
sub on_msg
{
  my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
  my @user = (split(/!/, $who));
  my $channel = $where->[0];
  my %info_to_pass = ('nick' => $user[0], 'ident' => $user[1], 'channel' => $user[0], 'command' => $msg, 'limit' => $config{'limit'});
  command(\%todo, \$irc, %info_to_pass);
}

exit 0;
