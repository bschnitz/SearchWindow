#!/usr/bin/perl

use File::Spec;

$filetype = @ARGV > 0 ? $ARGV[0] : "";
$file = "";
$numresults = 0;
@lines = ();

while(<STDIN>)
{
  chomp;

  ( $filenew, $linenr, $result ) = split( ":", $_, 3 );

  # Ergebnisse werden nach Datei gruppiert
  if( $file ne $filenew )
  {
    $fileabs = File::Spec->rel2abs($filenew);
    push @lines, sprintf( "\n%s", $fileabs );
    $file = $filenew;
  }

  if( $filetype eq "cpp" )
  {
    # nicht geschlossene mehrzeilige Kommentare (/* ...) schließen
    $result =~ s|(/\*((?!\*/).)*)$|$1 *** closed comment */|;

    # #if 0 abschließen
    $result =~ s|(#if\s*0.*)$|$1 #|;
  }

  push @lines, sprintf("%4d  %s", $linenr, $result);
  ++$numresults;
}

printf "%d results\n", $numresults;
for( @lines ){ printf("%s\n", $_); }
if( $filetype ne "" ) { printf "\n vim: set filetype=%s :", $filetype; }
