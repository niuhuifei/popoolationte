

# Introduction #

A simple and cheap approach to genome-wide assess TE insertion frequencies in populations will allow addressing fundamental questions about TE dynamics and species evolution in more general.

Here we introduce a novel and cost efficient approach to estimate TE population frequencies for TE insertions that are present in the reference sequence as well as for novel TE insertions. Our approach solely requires sequencing of a single paired-end (PE) sample of a pooled population per investigated population. Our approach has the additional advantage that sequencing of pooled populations also yields genome-wide estimates of SNP frequencies and thus standard population genetics measures such as Tajima’s D can easily be calculated http://code.google.com/p/popoolation/.

# Requirements #

  * paired-end sequences of a pooled population
  * a reference genome
  * a transposable element sequence database (i.e.: a fasta file containing sequences of TEs)
  * Perl
  * BWA
  * SAMtools
  * RepeatMasker
  * PoPoolation TE


# Workflow #

## Preparing the reference sequence ##

  1. Download a reference genome. Remove unnecessary comments from the fasta headers
```
cat dmel-all-chromosome-r5.31|awk '{print $1}' > ../wg/dmel-5.31-short.fasta
```
  1. Download the transposon sequences. Remove unnecessary comments from the fasta header
  1. Filter TE elements that are to short (e.g.: < 40bp)
  1. RepeatMask the reference genome using the transposon sequences as a custom library
```
perl RepeatMasker -no_is -nolow -norna --lib te-sequences.fasta -pa 4 reference-genome.fasta
```
  1. Merge the repeat-masked reference genome and the TE sequences
```
cat reference-genome.fasta.masked te-sequences.fasta > combined-reference.fasta
```


## Obtaining a TE hierarchy ##

Create a TE hierarchy containing one entry for EVERY sequence in the TE sequences fasta-file! The depth of the hierarchy, the classification of the elements and the names for different hierarchy-levels is up to the user!

example of an hierarchy file:
```
insert	id	family	superfamily	suborder	order	class	problem
FBti0015567	Tirant	Tirant	Tirant	LTR	LTR	RNA	0	
FBti0018861	17.6	17.6	17.6	LTR	LTR	RNA	0	
FBti0018862	17.6	17.6	17.6	LTR	LTR	RNA	0	
FBti0018865	297	297	297	LTR	LTR	RNA	0	
FBti0018869	3S18	3S18	3S18	LTR	LTR	RNA	0
FBti0018957	baggins	baggins	baggins	non-LTR	non-LTR	RNA	0
FBti0018944	Tc1	Tc1	Tc1	TIR	TIR	DNA	0
```

The first row specifies the names of the hierarchy-levels in ascending order. The problem column may be ignored
All other columns refer to individual TE sequences and their hierarchical status. For every entry in the TE-sequences fasta file the TE-hierarchy has to contain exactly one entry. Note that many individual entries may be present for TE insertions of the same family. The software tries to handle the resulting sequence ambiguity by moving in this TE-hierarchy.

## Mapping the sequences ##

  1. Index the reference genome
```
bwa index combined-reference.fasta
```
  1. Map the PE reads separately using BWA SW (Smith-Waterman algorithm)
```
bwa bwasw -t 6 combined-reference.fasta ../reads/Jul_s_5_1_sequence.txt > Jul_s_5_1_seq.sam
bwa bwasw -t 6 combined-reference.fasta ../reads/Jul_s_5_2_sequence.txt > Jul_s_5_2_seq.sam
```
  1. Create paired-end information using samro (PoPoolation TE)
```
perl samro.pl --sam1 Jul_s_5_1_seq.sam --sam2 Jul_s_5_2_seq.sam --fq1 ../reads/Jul_s_5_1_s
equence.txt --fq2 ../reads/Jul_s_5_2_sequence.txt --output pe-reads.sam
```
  1. Sort the sam file
The sam-file needs to be sorted with samtools
```
samtools view -Sb pe-reads.sam | samtools sort - pe-reads.sorted
samtools view pe-reads.sorted.bam > pe-reads.sorted.sam
```

## Identify TE insertions ##

  1. Identify forward and reverse insertions
```
perl identify-te-insertsites.pl --input pe-reads.sorted.sam --te-hierarchy-file te-hierarchy.txt --te-hierarchy-level family --narrow-range 75 --min-count 3 --min-map-qual 15 --output te-fwd-rev.txt
```
  1. Identify the positions of poly-N stretches in the repeat-masked reference genome. PoPoolation TE calculates the distance between forward and reverse insertions and ignores poly-N stretches for calculating these distances.
```
perl genomic-N-2gtf.pl --input combined-reference.fasta > poly_n.gtf
```
  1. Crosslink forward and reverse insertions thus obtaining TE insertions
```
perl crosslink-te-sites.pl --directional-insertions te-fwd-rev.txt --min-dist 74 --max-dist 250 --output te-inserts.txt --single-site-shift 100 --poly-n poly_n.gtf --te-hierarchy te-hierarchy.txt --te-hier-level order
```
  1. Optional: Use the known TE insertions to improve the crosslinking of forward and reverse insertions
```
perl update-teinserts-with-knowntes.pl --known known-te-insertions.txt --output te-insertions.updated.txt --te-hierarchy-file te-hierarchy.txt --te-hierarchy-level family --max-dist 300 --te-insertions te-inserts.txt --single-site-shift 100
```

The known TE insertion file has to look like in the following example:
```
2L      F       20740303        FBti0015567
2L      R       20748120        FBti0015567
2R      F       5614174 FBti0018861
2R      R       5621667 FBti0018861
```
Column1 is the reference chromosome, column2 the direction of the insertion either forward (F) or reverse (R), column3 is the position and
column4 is the fasta-header of the corresponding TE sequence (here the FlyBase ID)

## Estimate population frequencies ##
  1. Estimate population frequencies
```
perl estimate-polymorphism.pl --sam-file pe-reads.sorted.sam --te-insert-file te-insertions.updated.txt --te-hierarchy-file te-hierarchy.txt --te-hierarchy-level family --min-map-qual 15 --output te-polymorphism.txt
```
  1. Optional: Filter the file
```
perl filter-teinserts.pl --te-insertions te-polymorphism.txt --output te-poly-filtered.txt --discard-overlapping --min-count 10
```
  1. Voila: the output file
```
4       135417  F       G4      0.75    non-LTR -       -       135302  135317  0.75    4       3       1       1       -       -       -       -       -       -       -
4       135906  FR      G5      1       non-LTR FBti0020406     ncorrdist=105   135348  135447  1       17      17      0       0       136365  136464  1       74      74      0       0
4       135333  R       gypsy12 0.0784313725490196      LTR     -       -       -       -       -       -       -       -       -       135433  135491  0.0784313725490196      51      4       47      0
4       145298  FR      HB      1       TIR     FBti0062857     ncorrdist=99    144489  144588  1       23      23      0       0       146008  146085  1       47      47      0       1
4       146710  FR      Tc1     1       TIR     FBti0019474     ncorrdist=89    145963  146062  1       23      23      0       0       147358  147390  1       14      14      0       0
```
  * Col1: the reference sequence ID
  * Col2: position in the reference sequence
  * Col3: is the TE insertion supported by a forward (F), by a reverse (R) or by both (FR) insertions
  * Col4: family of the TE insertion
  * Col5: population frequency (1..fixed)
  * Col6: order of the TE insertion
  * Col7: ID if the TE insertion is present in the reference genome (e.g.: FlyBase ID)
  * Col8: comment
  * Col9: start of the range of the forward insertion
  * Col10: end of the range of the forward insertion
  * Col11: population frequency estimated by the forward insertion
  * Col12: coverage of the forward insertion
  * Col13: TE-presence reads of the forward insertion
  * Col14: TE-absence reads of the reverse insertion
  * Col15: is the range of the forward insertion overlapping with a forward-range of another TE insertion (0..no; 1..yes)
  * Col16: start of the range of the reverse insertion
  * Col17: end of the range of the reverse insertion
  * Col18: coverage of the reverse insertion
  * Col19: TE-presence reads of the reverse insertion
  * Col20: TE-absence reads of the reverse insertion
  * Col21: is the range of the reverse insertion overlapping with the reverese-range of another TE insertion (0..no; 1..yes)