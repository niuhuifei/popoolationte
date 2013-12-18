use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use File::Path;
use File::Basename; # to get the file path, file name and file extension
use FindBin qw/$RealBin/;
use lib "$RealBin/Modules";
use List::Util qw[min max];
use TEHierarchy;
use TEInsertUtility;
use TEInsert;
use Utility;

my $teinsertfile;
my $discardoverlapping=0;
my $output;
my $mincount=10;
my $help=0;
my $test=0;

GetOptions(
    "te-insertions=s"	    =>\$teinsertfile,
    "output=s"              =>\$output,
    "discard-overlapping"   =>\$discardoverlapping,
    "min-count=i"           =>\$mincount,
    "test"                  =>\$test,
    "help"	            =>\$help
) or pod2usage(-msg=>"Wrong options",-verbose=>1);

pod2usage(-verbose=>2) if $help;
pod2usage(-msg=>"Wrong options",-verbose=>1) unless $teinsertfile;


my $teinsertions=load_te_inserts($teinsertfile);

if($discardoverlapping)
{
    my($subclones,$famstat,$ordstat)=Utility::filter_not_overlapping($teinsertions);
    print "OVERLAPPING STATISTICS\nOverlapping Discarded by family:\n";
    while(my($fam,$count)=each(%$famstat))
    {
        print "$fam\t$count\n";
    }
    print "\nOverlapping Discarded by order:\n";
    while(my($ord,$count)=each(%$ordstat))
    {
        print "$ord\t$count\n";
    }
    print "\n\n";
    
    $teinsertions=$subclones;
}

if($mincount)
{
    my($subclones,$famstat,$ordstat)=Utility::filter_mincount($teinsertions,$mincount);
    print "MIN COUNT: $mincount STATISTICS\nDiscarded by family:\n";
    while(my($fam,$count)=each(%$famstat))
    {
        print "$fam\t$count\n";
    }
    print "\nDiscarded by order:\n";
    while(my($ord,$count)=each(%$ordstat))
    {
        print "$ord\t$count\n";
    }
    print "\n\n";
    
    $teinsertions=$subclones;
}

write_te_inserts($teinsertions,$output);
exit;


{
    package Utility;
    use strict;
    use warnings;
    
    sub filter_mincount
    {
        my $teinserts=shift;
        my $mincount=shift;
        
        my $famstat={};
        my $ordstat={};
        my $toret=[];
        
        foreach my $tei(@$teinserts)
        {
            my $fam=$tei->{teid};
            my $ord=$tei->{order};
            my $subclone=$tei->subclone_mincount($mincount);
            if($subclone)
            {
                push @$toret,$subclone;
            }
            else
            {
                $famstat->{$fam}++;
                $ordstat->{$ord}++;
            }
        }
        return ($toret,$famstat,$ordstat);
    }
    
    sub filter_not_overlapping
    {
        my $teinserts=shift;
        
        my $famstat={};
        my $ordstat={};
        my $toret=[];
        foreach my $tei(@$teinserts)
        {
            my $fam=$tei->{teid};
            my $ord=$tei->{order};
            my $subclone=$tei->subclone_notoverlapping();
            if($subclone)
            {
                push @$toret,$subclone
            }
            else
            {
                $famstat->{$fam}++;
                $ordstat->{$ord}++
            }
        }
        return ($toret,$famstat,$ordstat);
    }
}


#    "te-insertions=s"	    =>\$teinsertfile,
#    "output=s"              =>\$output,
#    "discard-overlapping"   =>\$discardoverlapping,
#    "min-count=i"           =>\$mincount,
#    "test"                  =>\$test,
#    "help"	            =>\$help
=head1 NAME

filter-teinserts.pl

=head1 SYNOPSIS

 filter-teinserts.pl --te-insertions infile.te --output filtered.te --discard-overlapping --min-count 10

=head1 OPTIONS

=over 4

=item B<--te-insertions>

The input file Mandatory parameter

=item B<--output>

The output file. Mandatory parameter

=item B<--discard-overlapping>

Flag; get rid of overlapping TE insertions; i.e.: overlapping ranges

=item B<--min-count>

The minimum number of absence and presence reads, i.e.: minimum number of PE fragments within the range

=item B<--test>

Run the unit tests for this script. 

=item B<--help>

Display help for this script

=back


=cut
