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

$file = "$header$file";
$fileLen = length($file);
print "Loaded document with $fileLen characters.\n";

print "Making edits...\n";
$file =~ s/^#/--/mg;
$file =~ s/^UNLOCK TABLES;$/-- UNLOCK TABLES;/mg;
$file =~ s/^LOCK TABLES "(.*)" WRITE;$/-- LOCK TABLES "$1" WRITE;/mg;
$file =~ s/(big|tiny|small)*int(\([0-9]+\)){0,1}( unsigned){0,1}/$1int/g;
$file =~ s/\\'/''/g;
$file =~ s/datetime/timestamp/ig;
$file =~ s/(.*)double (default|not null)(.*),/$1double precision $2$3,/ig;
$file =~ s/('[^'\\]*(?:\\.[^'\\]*)+')/E'$1'/g;

print "Warning: You have auto_increment columns in this schema.\n"
	if ($file =~ /auto_increment/);

print "Warning: You will need to change UNIQUE KEY $1 ($2) to UNIQUE $2\n"
	while ($file =~ m/UNIQUE KEY "(.*)" \((.*)\)/g);

print "Warning: You will need to change KEY $1 ($2) to create index on <table> ($2);\n"
	while ($file =~ m/^  KEY "(.*)" \((.*)\)/mg);

print "Writing final file...\n";
write_file("$path.out", \$file);

print "Ended run\n";
exit(0);
