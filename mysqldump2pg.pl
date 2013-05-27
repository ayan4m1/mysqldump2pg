#!/usr/bin/perl
# mysqldump2pg by ayan4m1

use File::Slurp qw(prepend_file read_file write_file);
use File::Copy;

my $path = shift(@ARGV);
die "No path was specified!\n" unless defined($path);

print "Reading $path...\n";
my $file = read_file($path);
my $header = <<EndHeader
SET standard_conforming_strings = 'off';
SET backslash_quote = 'on';
EndHeader
;

print "Prepending header\n";
$file = "$header$file";

print "Making edits...\n";

# fix comments
$file =~ s/^#/--/mg;

# replace backticks with double quotes
$file =~ s/`/"/g;

# strip engine/charset from end of create table
$file =~ s/^\s*\)\s+(engine|default|character).*$/);/img;

# comment out table lock/unlocks
$file =~ s/^unlock tables;$/-- unlock tables;/img;
$file =~ s/^lock tables "(.*)" write;$/-- lock tables "$1" write;/img;

# comment out data dictionary comments
$file =~ s/^(.*) comment [\'\"](.*)[\'\"],/$1, -- $2/img;

# data types
$file =~ s/(big|tiny|small)*int(\([0-9]+\)){0,1}( unsigned){0,1}/$1int/ig;
$file =~ s/datetime/timestamp/ig;
$file =~ s/(.*)double (default|not null)(.*),/$1double precision $2$3,/ig;

# enable escape sequence parsing in strings
$file =~ s/('[^'\\]*(?:\\.[^'\\]*)+')/E$1/g;

# replace escaped quotes
$file =~ s/\\'/''/g;

print "Warning: You have auto_increment columns in this schema.\n"
	if ($file =~ /auto_increment/);

print "Warning: You will need to change UNIQUE KEY $1 ($2) to UNIQUE $2\n"
	while ($file =~ m/UNIQUE KEY "(.*)" \((.*)\)/g);

print "Warning: You will need to change KEY $1 ($2) to create index on <table> ($2);\n"
	while ($file =~ m/^  KEY "(.*)" \((.*)\)/mg);

print "Writing final file...\n";
write_file("$path.out", \$file);

