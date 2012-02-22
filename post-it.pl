#!/usr/bin/env perl
# See LICENCE for licence details
# Or go to http://files.entropy.net.nz/LICENCE

use warnings;
use strict;
use POE;
use POE::Component::IRC;
use utils;


my ($irc, $server, $port, $ownernick, $nickname, %config, %todo);
my @help = ("post-it - To-do list/reminder IRC bot\n",
"Commands:\n",
"!todo list <n>          Show your to-do list, or the nth item if given.\n",
"!todo add <reminder>    Add <reminder> to your list\n",
"!todo remove <text>     Remove all reminders containing <text>\n",
"!todo removepos <n>     Remove remonder at position <n>\n");

sub command
{
  my ($todo_ref, $irc, %info) = @_;
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
          chomp($_);
          push(@{$todo_ref->{$info{'ident'}}}, $_);
        }
        close(TODO);
        print "Loaded todo list for $info{'ident'}\n";
      }
      else
      {
        print "No list exists.\n";
      }
    }

    # todo list
    if ($command =~ /^!todo( list)* *(\d+)*$/)
    {
      if ($2 ne "")
      {
        list($todo_ref, $irc, $2 ,%info)
      }
      else
      {
        list($todo_ref, $irc, 0, %info);
      }
    }
    # add to list
    elsif ($command =~ /^!todo add (.+)$/)
    {
      add($todo_ref, $irc, %info);
    }

    #todo remove
    elsif ($command =~ /^!todo remove (.+)$/)
    {
      remove($todo_ref, $irc, %info);
    }

    # remove at position
    elsif ($command =~ /^!todo removepos (\d+)/)
    {
      removepos($todo_ref, $irc, %info);
    }

    # get help from the bot
    elsif ($command =~ /^!todo help/)
    {
      foreach my $line (@help)
      {
        $$irc->yield('privmsg', $info{'nick'}, "$line");
      }
    }
  }
}

# add to the todo list
sub add
{
  my ($todo_ref, $irc, %info) = @_;
  push(@{$todo_ref->{$info{'ident'}}}, $1) if ($todo_ref->{$info{'ident'}});
  open(TODO, ">>", "$info{'ident'}.todo") || warn "Could not open to-do list file: $!\n";
  return if (tell(TODO) == -1);
  print "Writing $1 to $info{'ident'}'s list\n";
  print TODO "$1\n";
  close(TODO);
}

# list all items in todo list
sub list
{
  my ($todo_ref, $irc, $index, %info) = @_;
  # all lines
  return if not $todo_ref->{$info{'ident'}};
  return if ($#{$todo_ref->{$info{'ident'}}} < 0);
  $index = 0 if $index < 0;
  $index = $#{$todo_ref->{$info{'ident'}}} if $index > $#{$todo_ref->{$info{'ident'}}};
  
  $$irc->yield('privmsg', $info{'nick'}, "$info{'nick'}'s to-do list: (" . ($#{$todo_ref->{$info{'ident'}}}+1) . " items)");
  for (my $i = $index; $i < @{$todo_ref->{$info{'ident'}}}; $i++)
  {
    if ($i > ($index + $info{'limit'} - 1))
    {
      $$irc->yield('privmsg', $info{'nick'}, "---Limit reached.---");
      return;
    }
    $$irc->yield('privmsg', $info{'nick'}, "$i: ${$todo_ref->{$info{'ident'}}}[$i]");
  }
}

# list nth item in todo list
sub listone
{
  my ($todo_ref, $irc, $index, %info) = @_;
  if ($todo_ref->{$info{'ident'}})
  {
    $index = 0 if $index < 0;
    $index = $#{$todo_ref->{$info{'ident'}}} if $index > $#{$todo_ref->{$info{'ident'}}};
    return if $index < 0;
    $$irc->yield('privmsg', $info{'nick'}, "Item no. $index: ${$todo_ref->{$info{'ident'}}}[$index]");
  }
}

# remove all matvhing entries
sub remove
{
  my ($todo_ref, $irc, %info) = @_;
  my @removes;
  my @removes_indices;
  # find items to remove
  for (my $i = 0; $i < @{$todo_ref->{$info{'ident'}}}; $i++)
  {
    if (${$todo_ref->{$info{'ident'}}}[$i] =~ /$1/)
    {
      my $remove = ${$todo_ref->{$info{'ident'}}}[$i];
      chomp $remove;
      print "Will remove $remove\n";
      push(@removes, $remove);
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
      print TODO "$entry\n";
      print "Writing $entry";
    }
    close(TODO);
    $$irc->yield('privmsg', $info{'nick'}, "Removed: ".join(", ", @removes));
  }
}

sub removepos
{
  my ($todo_ref, $irc, %info) = @_;
  return if not ($todo_ref->{$info{'ident'}});
  if ($1 > $#{$todo_ref->{$info{'ident'}}})
  {
    $$irc->yield('privmsg', $info{'channel'}, "Index $1 is larger than the last index of your todo list (" . ($#{$todo_ref->{$info{'ident'}}}) + 1) . "items.");
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
      print TODO "$entry\n";
      print "Writing $entry\n";
    }
    close(TODO);
    $$irc->yield('privmsg', $info{'nick'}, "Removed: $removed");
  }
}

#############################
####### IRC functions #######
############################
# The bot session has started. Select a nickname. Connect to a server.
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

# The bot has successfully connected to a server. Join the configured channel
sub on_connect
{
  print "Successfully connected.\n";
  print "Joining $config{'channel'}\n";
  $irc->yield(join => $config{'channel'});
}

# The bot has disconnected from the server, exit.
sub on_disconnect
{
  print "Disconnected from server\n";
  exit 0;
}

# Socket error, print the error and exit.
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

exit 0;
