#!/usr/bin/env perl

package utils;
use warnings;
use strict;

# parse a config file
sub parse_config
{
  my $config_file = $_[0];
  my (%settings, @setting, $line);
  open(SETTINGS, "<", "$config_file") || warn "Could not open $config_file: $!\n";
  return if (tell(SETTINGS) == -1);
  while(<SETTINGS>)
  {
    chomp($line = $_);
    next if ($line =~ /^#/);
    @setting = split(/\s*=\s*/, $line, 2) if ($line =~ /=/);
    $settings{$setting[0]} = $setting[1];
  }
  close(SETTINGS);
  return %settings;
}

1;
