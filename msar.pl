#!/usr/bin/perl
##################################################
# AUTHOR = Michael Vincent
# www.VinsWorld.com
##################################################

use vars qw($VERSION);

$VERSION = "1.5 - 20 JUL 2015";

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);    #bundling
use Pod::Usage;

##################################################
# Start Additional USE
##################################################

##################################################
# End Additional USE
##################################################

my %opt;
my ( $opt_help, $opt_man, $opt_versions );

GetOptions(
    ''            => \$opt{mapfile},     # lonesome dash is mapfile from STDIN
    'all!'        => \$opt{all},
    'beep!'       => \$opt{beep},
    'columns=s'   => \$opt{cols},
    'debug!'      => \$opt{debug},
    'ignore!'     => \$opt{ignore},
    'reverse!'    => \$opt{reverse},
    'separator=s' => \$opt{separator},
    'words!'      => \$opt{words},
    'help!'       => \$opt_help,
    'man!'        => \$opt_man,
    'versions!'   => \$opt_versions
) or pod2usage( -verbose => 0 );

pod2usage( -verbose => 1 ) if defined $opt_help;
pod2usage( -verbose => 2 ) if defined $opt_man;

if ( defined $opt_versions ) {
    print
      "\nModules, Perl, OS, Program info:\n",
      "  $0\n",
      "  Version               $VERSION\n",
      "    strict              $strict::VERSION\n",
      "    warnings            $warnings::VERSION\n",
      "    Getopt::Long        $Getopt::Long::VERSION\n",
      "    Pod::Usage          $Pod::Usage::VERSION\n",
##################################################
# Start Additional USE
##################################################

##################################################
# End Additional USE
##################################################
      "    Perl version        $]\n",
      "    Perl executable     $^X\n",
      "    OS                  $^O\n",
      "\n\n";
    exit;
}

##################################################
# Start Program
##################################################

my @mapOrder;
my ( %SAR, %map );
my $NOMapping  = 0;
my $YESMapping = 0;
my ( $infile, $mapfile, $outfile, $OUT );

$opt{separator} = $opt{separator} || "\t";

# Must be argv0 = infile
if ( $ARGV[0] ) {
    if ( !( -e ( $infile = $ARGV[0] ) ) ) {
        print "$0: Cannot find input_file - $infile\n";
        exit;
    }
} else {
    pod2usage( -verbose => 0, -message => "$0: input_file required\n" );
}

# There must be argv1 = mapfile or lonesome -
if ( defined $opt{mapfile} ) {
    $mapfile = 'STDIN';

    # If another ARGV, it must be outfile, (since skipping mapfile) so add it
    if ( $ARGV[1] ) { push @ARGV, $ARGV[1] }
} else {
    if ( $ARGV[1] ) {
        if ( !( -e ( $mapfile = $ARGV[1] ) ) ) {
            print "$0: Cannot find map_file - $mapfile\n";
            exit;
        }
    } else {
        pod2usage( -verbose => 0, -message => "$0: map_file required\n" );
    }
}

# There MAY be argv2 = outfile
if ( $ARGV[2] ) { $outfile = $ARGV[2] }

# Specified columns?
if ( defined $opt{cols} ) {
    $opt{cols} = &GET_RANGE_ARGS( $opt{cols} );
}

# We'll use a hash called SAR that will have keys of the columns' numbers to
# replace and the column numbers as the values (just cause).  Later, we can
# just search for a "key" in the hash that corresponds to the column number
# and replace.  Easier than searching through an array to see if a value exists.
if ( defined $opt{cols} ) {

    # Convert array to a hash, decrementing as the user will enter '1'
    # for column 1, but PERL starts arrays at 0.
    #     $columnArray[1] -> $SAR{0} = 0
    #     $columnArray[2] -> $SAR{1} = 1
    #     ... and so on
    for ( @{$opt{cols}} ) {
        $SAR{$_ - 1} = $_ - 1;
    }
}

# Read in Mappings
#
# If we ignore case with -i, we're going to force the hash index (SEARCH)
# to be lowercase and read in the columns from the input file in lowercase.
# The actual REPLACE values will always be read/used in their entered case.
#
# We'll also set a variable for the order in which we read in the hash
# since hashes have no sort order and can't guarantee they will be output
# in the same order they were input.  We could use Tie::IxHash for this,
# but this seems so much easier.  We'll only need this if we're not looking
# at columns (-c option) because with that option, we look at the whole
# "word" in the column at once rather than a string SAR with s///g.

if ( $mapfile eq 'STDIN' ) {
    print "Reading mappings from STDIN\n";
    print "----------------------------\n";
    my $MAPFILE = \*STDIN;
    ReadMapFile($MAPFILE);
} elsif ( open( my $MAPFILE, '<', "$mapfile" ) ) {
    print "Reading mappings from file:  $mapfile\n";
    print "----------------------------\n";
    ReadMapFile($MAPFILE);
    close $MAPFILE;
} else {
    print "$0: Cannot open mapping file - $mapfile\n";
    exit 1;
}

# We open the outfile here if the user specified one.
my $OUTFILE;
if ($outfile) {
    print "[--Output printing to file:  $outfile--]\n";
    if ( !( open( $OUTFILE, '>', "$outfile" ) ) ) {
        print "$0: Cannot open output file - $outfile\n";
        exit 1;
    }
    $OUT = $OUTFILE;
} else {
    $OUT = \*STDOUT;
}

# Perform SAR
if ( open( my $INFILE, '<', "$infile" ) ) {
    while (<$INFILE>) {

        chomp $_;

        # if columnArray is specified, the user submitted columns, otherwise
        # we're just going to do SAR on each line
        if ( $opt{cols} ) {

            # Split the line by tabs
            my @array = split( /$opt{separator}/, $_ );

            for ( 0 .. $#array ) {

                # Formatting:, print tabs AFTER each entry, not before the first
                # and do it here so we don't print one after the last.
                #
                # NOTE:  All following prints during the SAR will look like this.
                #        This allows us to print to either STDOUT or the outfile
                #        if the user provided one.
                if ( $_ > 0 ) {
                    print $OUT "$opt{separator}";
                }

                # If $_, the current column on the current line exists in the SAR
                # hash, the it is scheduled for replacement.  If not, just print it.
                if ( defined $SAR{$_} ) {
                    if ( $_ eq $SAR{$_} ) {

                        # So we're going to replace it, verify there is a mapping for it.
                        my $output
                          = ( $opt{ignore} )
                          ? $map{lc( $array[$SAR{$_}] )}
                          : $map{$array[$SAR{$_}]};

                        # $output may not be defined if there is no mapping in the map file
                        # as assigned in the above line.
                        if ( defined $output ) {
                            print $OUT "$output";
                            $YESMapping++;
                        } else {
                            if ( $opt{all} ) {
                                print $OUT "NOMAP:\[$array[$SAR{$_}]\]";
                                $NOMapping++;
                            } else {
                                print $OUT "$array[$SAR{$_}]";
                            }
                        }
                    }
                } else {
                    print $OUT "$array[$_]";
                }
            }    # for loop
            print $OUT "\n"

              # user didn't specify columns, so just SAR each line and leave alone
        } else {

            # Loop through mapping array values (the search strings).  Seems confusing
            # to use $replace, but the search string is a key to the $map hash that
            # contains the actual replace string.
            for my $replace (@mapOrder) {

                if ( defined( $opt{debug} ) ) {
                    print "  Search  : $_\n";
                    print "  For     : $replace\n";
                    print "  Replace : $map{$replace}\n";
                    print "  ---------\n";
                }

                # Whole word searches means the search string needs to have the
                # \b delimiters on both sides.
                my $search
                  = ( defined $opt{words} )
                  ? ( '\b' . $replace . '\b' )
                  : $replace;

                # ignore case?
                if ( defined $opt{ignore} ) {
                    $YESMapping += ( $_ =~ s/$search/$map{$replace}/gi );
                } else {
                    $YESMapping += ( $_ =~ s/$search/$map{$replace}/g );
                }
            }
            print $OUT "$_\n";
        }
    }    # END while
    close $INFILE

} else {
    print "$0: Cannot open input file - $infile\n";
    exit 1;
}

# if there was an outfile we need to close it now
if ($outfile) {
    close $OUTFILE;
}

if ( defined $opt{beep} ) {
    print "\a";
}

print "----------------------------\n";
if ( $opt{cols} ) {
    if ( !$opt{all} ) {
        print "Mapped $YESMapping entries.\n";
    } elsif ( $opt{all} && $NOMapping ) {
        print "Could not find mapping for $NOMapping entries.\n";
    } else {
        print "All entries mapped successfully.\n";
    }
} else {
    print "Mapped $YESMapping entries.\n";
}

exit 0;

##################################################
# Start Subs
##################################################
sub GET_RANGE_ARGS {

    my ($opt) = @_;

    # If argument, it must be a number range in the form:
    #  1,9-11,7,3-5,15
    # That is, only numbers, dash "-", or comma ","
    if ( $opt !~ /^\d+([\,\-]\d+)*$/ ) {
        print "$0: range only allows number, dash '-' or comma ','\n";
        exit 1;
    }

    my ( @option, @temp, @ends );

    # Split the string at the commas first to get
    #
    #  1   9-11   7   3-5   15
    #
    @option = split( /,/, $opt );

    # Now we'll loop through the remaining values to see if there are
    # dashes.  Dashes means all numbers between, inclusive.  Thus, we'll
    # need to expand the ranges and put the values in the array.
    for $opt (@option) {

        # If the value we're looking at has a dash '-', we'll split and add the 'missing' numbers.
        if ( $opt =~ /-/ ) {

            # Ends will be the start and stop number of the range.  For example, when $opt = 9-11:
            # $ends[0] = 9
            # $ends[1] = 11
            @ends = split( /-/, $opt );

            for ( $ends[0] .. $ends[1] ) {
                push @temp, $_;
            }

            # If the current $opt doesn't have a dash '-', then just move on
        } else {
            push @temp, $opt;
        }
    }

    # return the sorted values of the temp array
    @temp = sort { $a <=> $b } (@temp);
    return wantarray ? @temp : \@temp;
}

sub ReadMapFile {

    my ($MAPFILE) = @_;

    my $i = 0;
    while (<$MAPFILE>) {

        # skip blank lines and #comments
        next if ( ( $_ =~ /^[\n\r]+$/ ) || ( $_ =~ /^#/ ) );
        chomp $_;
        my @array = split( /$opt{separator}/, $_ );

        if ( !defined $array[1] ) {
#            if ($opt{cols}) {
            $array[1] = ""
#            } else {
#                close $MAPFILE;
#                print "$0: mapfile must have 2 tab-separated columns (no blanks) unless -c specified\n";
#                exit
#            }
        }

        # Shorter code thanks to GRAFF:  http://www.perlmonks.org/?node_id=751368
        # Determine non/reverse:
        my ( $pos1, $pos2 ) = ( $opt{reverse} ) ? ( 1, 0 ) : ( 0, 1 );

        # Determine case in/sensitive
        my $key = ( $opt{ignore} ) ? lc( $array[$pos1] ) : $array[$pos1];

        # Assign:
        $map{$mapOrder[$i] = $key} = $array[$pos2];
        $i++;
    }
}

__END__

=head1 NAME

MSAR - Multiple or Mapping Search and Replace

=head1 SYNOPSIS

 msar [options] input_file map_file|- [out_file]

=head1 DESCRIPTION

Script searches and replaces multiple text items based on a mapfile.

=head1 ARGUMENTS

 input_file          Text file.  Can be normal text or tab-delimited 
                     columns if using -c argument below.

 map_file            Text file mapping search name with replace name in 
                     two columns in the following format:

                          SEARCH_STRING1    REPLACE_STRING1
                          SEARCH_STRING2    REPLACE_STRING2
                                .                  .
                                .                  .
                                .                  .

                     Search and Replace strings are *TAB*-delimited.
                       (see -s below).
                     Search string *IS* case sensitive (see -i below).
                     Search string *IS* regex if *NOT* -c below.

                     If '-', read search/replace pairs from STDIN.

=head1 OPTIONS

 -a                  Map all items in provided -c argument.  If match is
 --all               not found, print "NOMAP:[string]" where 'string' 
                     is the unmappable string from the input file (without 
                     the double-quotes).

 -b                  Beep on completion.
 --beep

 -c #[range]         Columns to perform search and replace on. Columns 
 --columns           are numbered from left to right starting with 1.  
                     Range can be provided with comma "," for individual 
                     lines and dash "-" for all inclusive range.  

                     For example:

                                1,9-11,7,3-5,15

                     Searches and replaces on columns:

                                1 9 10 11 7 3 4 5 15

                     Output will be tab-delimited.

                     DEFAULT:  (or not specified) Search and Replace on 
                               each individual line of input file.

 -d                  Print verbose search and replace information.
 --debug

 -i                  Ignore case of search item from map file during 
 --ignore            search and replace.

 -r                  Reverse reading of mapping file from:
 --reverse
                          SEARCH_STRING1    REPLACE_STRING1
                          SEARCH_STRING2    REPLACE_STRING2
                                .                  .
                                .                  .

                     to:

                          REPLACE_STRING1    SEARCH_STRING1
                          REPLACE_STRING2    SEARCH_STRING2
                                .                  .
                                .                  .

 -s SEP              Use SEP as the separator between columns.
 --separator         DEFAULT:  (or not specified) [Tab].

 -w                  Search and replace full words only.  This is
 --words             implied with -c column option.

 out_file            Optional text file to send output.
                     DEFAULT:  (or not specified) To screen (STDOUT).

 --help              Print Options and Arguments.
 --man               Print complete man page.
 --versions          Print Modules, Perl, OS, Program info.

=head1 EXAMPLES

For the following examples, assume an input file with tab delimited 
columns called "in.txt":

  Col1    Col2    Col3
          Col2    Col3    Col4
   COL1   COL2    COL3
  col1    col2    col3

Also, assume a map file with tab delimited columns called "map.txt":

  Col1    Column1
  Col2    Column2
  Col3    Column3
  Column4 Col4

=head2 SIMPLE SEARCH AND REPLACE

This is executed across all of "in.txt" and is case sensitive.  Notice 
nothing in the last two rows is changed because the case in the map 
file is different than that in the input file.

  C:> msar in.txt map.txt
  Reading mappings from file:  map.txt
  ----------------------------
  Column1 Column2 Column3
          Column2 Column3 Col4
   COL1   COL2    COL3
  col1    col2    col3
  ----------------------------
  Mapped 5 entries.

=head2 SIMPLE SEARCH AND REPLACE WITH IGNORE CASE

Notice with ignore case on (-i), all rows are mapped.

  C:> msar in.txt map.txt -i
  Reading mappings from file:  map.txt
  ----------------------------
  Column1 Column2 Column3
          Column2 Column3 Col4
   Column1Column2 Column3
  Column1 Column2 Column3
  ----------------------------
  Mapped 11 entries.

=head2 COLUMN SEARCH AND REPLACE WITH CHECK FOR ALL

In this example, we limit the search and replace to the first and third 
columns of "in.txt".  Also, we specify we want all entries mapped (-a) 
regardless of whether there is an entry in the map file "map.txt".  If 
we can't find an entry in "map.txt", insert a "NOMAP:[string]", where
'string' is the text in "in.txt" that does not have a replace string 
in "map.txt".

  C:> msar in.txt map.txt -c 1,3 -i -a
  Reading mappings from file:  map.txt
  ----------------------------
  Column1 Col2    Column3
  NOMAP:[]        Col2    Column3 Col4
  NOMAP:[ COL1]     COL2    Column3
  Column1 col2    Column3
  ----------------------------
  Could not find mapping for 2 entries.

Notice there is no entry in row 2, column 1 of "in.txt", so that 
generates the "NOMAP:[string]" error.  In this case, 'string' is
blank as there is no text.  Also, row 3 of column 1 has an error 
because the text " COL1" (with the leading space) is not in the 
"map.txt" file.  Also note that since the "NOMAP:[ COL1]" error is so 
many characters, we run into column 2.  This looks wrong in simple text, 
but rest assured, there is a tab delimiting the columns so if you were 
to open the output in a spreadsheet application, the columns would line 
up appropriately.

=head2 FILE CREATION WITH TEMPLATE 

For the following example, assume an input file called "template.txt":

  hostname <HOSTNAME>

  interface eth0
   ip address <IPADDRESS> 255.255.255.0

Also, assume a map file with tab delimited columns called "map.txt":

  <IPADDRESS>    192.168.1.1    192.168.2.1    192.168.3.1
  <HOSTNAME>     host1          host2          host3

An output file creator is made with a for loop and Perl:

=head3 Windows

  for %i in (1 2 3) do @(
  perl -ane "print\"$F[0]\t$F[%i]\n\"" map.txt | ^
  msar template.txt - out%i.txt
  )

=head3 Unix

  for i in 1 2 3;
  do 
      perl -ane 'print"$F[0]\t$F['${i}']\n"' map.txt | 
      msar.pl template.txt - out${i}.txt;
  done

=head2 GOTCHA

For the following example, assume an input file "in.txt":

  april
  barrel

Also, assume a map file with tab delimited columns called "map.txt":

  Il      1
  April   2
  barrel  3
  PR      4

  C:> msar in.txt map.txt -i
  Reading mappings from file:  map.txt
  ----------------------------
  a41
  3
  ----------------------------
  Mapped 3 entries.

What happened here?  Without the columns argument (-c), the search and 
replace is performed over the whole line of "in.txt" for EACH mapping 
in "map.txt" in order of "map.txt".  Thus, on the first pass we have:

  SEARCH FOR   : Il
  IN IN.TXT    : april
  REPLACE WITH : 1
  RESULT       : apr1

The next pass is with line 2 of "map.txt":

  SEARCH FOR   : April
  IN IN.TXT    : apr1   (Remember, result of first pass)
  REPLACE WITH : 2
  RESULT       : apr1

Even with the case insensitive argument, we won't match what was "april"
on line 1 of "in.txt" because we already changed it to "apr1".  Next 
comes an uneventful pass 3:

  SEARCH FOR   : barrel
  IN IN.TXT    : apr1
  REPLACE WITH : 3
  RESULT       : apr1

Finally, the coup-de-grace on pass 4:

  SEARCH FOR   : PR
  IN IN.TXT    : apr1
  REPLACE WITH : 4
  RESULT       : a41

Then the (in this case) 4-step process for each line in "map.txt" is 
repeated for the next line in "in.txt", which results in the text 
"barrel" being replaced by "3" on the third pass.

THE MORAL:  Be careful and mind the order of entries in the "map.txt" 
file.  You can watch this search and replace happen with the debug option 
(-d).  You can avoid this pitfall by using the -c option if your infile 
is in columns or by using the -w option if you're parsing text not in 
columns.

=head1 LICENSE

This software is released under the same terms as Perl itself.
If you don't know what that means visit L<http://perl.com/>.

=head1 AUTHOR

Copyright (C) Michael Vincent 2008-2015

L<http://www.VinsWorld.com>

All rights reserved

=cut
