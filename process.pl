#!/usr/bin/perl

use strict;
use warnings;

my $file = $ARGV[0];
my $summary_file = $ARGV[1];

die "process.pl *data_file* *summary_file*\n" unless $summary_file;

open(my $data, '<', $file) or die "Could not open '$file' $!\n";
my $summary_data = load_summary_data($summary_file);

my $headings_map;

my $new_headings = [
'date',
'time',
'max_depth',
'cylinder_number',
'active_cylinder_pressure'
];

my $headings_done = 0;
my $max_depth = 0;
my $active_cylinder = 0;
my $active_cylinder_pressure = 0;
my $seen_pressure = 0;
my $seconds = 0;

while (my $line = <$data>)
{
	my $row = decode_csv($line);
	if ($headings_done == 0)
	{
		$headings_map = index_headings($row);

		print encode_csv([ @{$row}, @{$new_headings} ]);

		$headings_done = 1;
		next;
	}

	my $output_row = [];

	foreach my $i (0 .. $#{$row})
	{
		my $heading = $headings_map->{$i};
		my $value = $row->[$i];

		if ($heading eq 'depth')
		{
			$max_depth = $value if $value > $max_depth;
		}

		$seconds = $value if ($heading eq 'sec');

		if ($heading =~ m/^pressure_([0-9])_cylinder$/)
		{
			$value  += $row->[$i+1];

			$seen_pressure = 1 if ($value);

			if ($1 == 0 && $value == 0 && !$seen_pressure)
			{
				$value = $summary_data->{'startpressure (bar)'} * 1000;
			}

			if ($value > 0)
			{
				$active_cylinder = $1;
				$active_cylinder_pressure = $value;
			}
		}

		push @{$output_row}, $value;
	}

	push @{$output_row}, $summary_data->{date};
	push @{$output_row}, add_time($summary_data->{time}, $seconds);
	push @{$output_row}, $max_depth;
	push @{$output_row}, $active_cylinder;
	push @{$output_row}, $active_cylinder_pressure;



	print encode_csv($output_row);


}


sub add_time
{
	my ($time, $seconds) = @_;

	my ($h,$m,$s) = split(':',$time);

	my $total = ($h*60*60)+($m+60)+$s+$seconds;

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($total);

	return "$hour:$min:$sec";
}

sub load_summary_data
{
	my ($file) = @_;

	open(my $data, '<', $file) or die "Could not open '$file' $!\n";

	my @lines = <$data>;
	
	my $headings = decode_tsv($lines[0]);
	my $values = decode_tsv($lines[1]);

	my $summary_data = {};
	foreach my $i (0..$#{$headings})
	{
		$summary_data->{$headings->[$i]} = $values->[$i];
	}	
	return $summary_data;
}

sub decode_tsv
{
	my ($string) = @_;

	$string =~ s/"//g;
	$string =~ s/[\n\r]//g;
	return [split(/ *\t */,$string)];

}

sub decode_csv
{
	my ($string) = @_;

	$string =~ s/"//g;
	$string =~ s/[\n\r]//g;
	return [split(/\s*,\s*/,$string)];
}

sub encode_csv
{
	my ($arrayref) = @_;

	return join(',',@{$arrayref}) . "\n";
}

sub index_headings
{
	my ($headings) = @_;

	my $map = {};

	my $i = 0;

	foreach my $h (@{$headings})
	{
		$map->{$i} = $h;
		$i++;
	}
	return $map;
}

