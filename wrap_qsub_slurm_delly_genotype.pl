#!/usr/bin/perl

### Version 1.0 -- 19 August 2012 -- Zach Gompert
### a perl script to submit many serial slurm jobs to the queue using the sbatch command.  
## usage: perl wrap_qsub_slurm_bwa_mem.pl ../../whole_genomes/sequences/*3kb*fastq.gz
use warnings;
use strict;

### ------------------ JOB CONFIGURATION ----------------------- 
### You will probably need to modify some of these variables


my $walltime = '90:00:00'; ## Format: hh:mm:ss
# Specify the maximum wall clock time for a single job. The
# wall clock time should take possible queue waiting time into
# account.  Format: hhhh:mm:ss hours:minutes:seconds Be sure to
# specify a reasonable value here.  If the job does not finish by the
# time reached, the job is terminated.

my $nodes = '1'; # Request number of compute nodes per job.
my $ppn = '20'; # Number of tasks per node
my $accnt= 'usubio-kp'; # PI account
my $partition = 'usubio-kp'; # Specify compute cluster, options include
		# kingspeak, ember, kingspeak-freecylce, ember-freecycle

my $jobname = 'delly';
#          Set the name of the job (up to 15 characters, 
#          no blank spaces, start with alphanumeric character)

my $email = 'samridhi.chaturvedi@gmail.com'; ## e-mail this address if the job fails

## build array of jobs to be run individually (serially) by slurm
my $dir = '/uufs/chpc.utah.edu/common/home/gompert-group1/data/lycaeides/lyc_sv/Alignments/';
my @jobarray;
my $aln;
#my $samse;
my $ind;
my $id;
my $in1;
my $in2;
my $in;
my $sample;
my $genome = "/uufs/chpc.utah.edu/common/home/gompert-group3/data/LmelGenome/Lmel_dovetailPacBio_genome.fasta";
my $resdir = '/uufs/chpc.utah.edu/common/home/gompert-group1/data/lycaeides/lyc_sv/Variantcalling/delly'; 
my $sites = '/uufs/chpc.utah.edu/common/home/gompert-group1/data/lycaeides/lyc_sv/Variantcalling/delly/sites.bcf';
my $cd = "cd $dir\n";

my @job;
my $job;
my $cnt = 0;

#myregex = ([A-Z])\w+\-\d+|([A-Z])|\d+|\-|.fastq
for my $file (@ARGV){
	$file =~ m/([a-z]+\_3kb\_1\.fastq\.gz\.sorted\.bam)/ or die "failed sub $file\n";
	#print "$file";
    	$id = $1;
	#print "$id";
    	$ind = "$1";
	#print "$ind";
    	$in = "$id";
	#print "$in";
	#$in1 = $in;
	#$in1 =~ s/1.fastq/1.fastq/;
	#print "$in1";
	#$in1 =~ s/1\.fastq//;
    	#$in2 = $in;
    	#$in2 =~ s/1\.fastq/2.fastq/;
	#print "$in2";
    #print "$in $in2 $ind $run $pnum\n";
    	$aln = "/uufs/chpc.utah.edu/common/home/gompert-group1/data/lycaeides/lyc_sv/Programs/delly/src/delly call -g $genome -v $sites -o $resdir"."$ind".".geno.bcf $in\n";
	push (@jobarray, "$cd"."$aln");
    	print "$cd"."$aln";

}


printf "Ready to submit %d jobs to slurm (y/n): ", scalar @jobarray;
my $response = <STDIN>;
chomp $response;
if($response eq 'n'){
    print "Exiting without any slurm submissions.\n";
    exit;
}
else{
    print "Proceeding with slurm submission\n";
}
## -----------------------------------------------------------------




###### ------------------ SLURM CONFIGURATION ---------------
my @directives = "#!/bin/sh -f\n";

push @directives, "#SBATCH --time=$walltime\n";
push @directives, "#SBATCH --nodes=$nodes\n";
push @directives, "#SBATCH --ntasks=$ppn\n";
push @directives, "#SBATCH --account=$accnt\n";
push @directives, "#SBATCH --partition=$partition\n";
push @directives, "#SBATCH --job-name=$jobname\n";
push @directives, "#SBATCH --mail-type=FAIL\n";
push @directives, "#SBATCH --mail-user=$email\n";


my $directives = join '', @directives;

##########################################
#                                        #
#   Output some useful job information.  #
#                                        #
##########################################

my @slurmjob = ();
push @slurmjob, '
    echo ------------------------------------------------------
    echo -n \'Job is running on node \'; cat $SLURM_JOB_NODELIST
    echo ------------------------------------------------------
    echo SLURM: job identifier is $SLURM_JOBID
    echo SLURM: job name is $SLURM_JOB_NAME
    echo ------------------------------------------------------

';

##############################################################
#                                                            #
#   The prolog script loads necessary modules                #
#                                                            #
##############################################################

push @slurmjob, "module load gcc\n";
push @slurmjob, "module load gsl\n";
push @slurmjob, "module load hdf5\n";
push @slurmjob, "module load bwa\n";
## add other needed modules below


############################################################
#                                                          #
#    Execute the run.  Do not run in the background.       #
#                                                          #
############################################################

## gather everything up to this point, use join with ""
my $prolog = join '', @slurmjob;
@slurmjob = ();

## this is where we would put if this were not in a perl wrapper:
## program_executable < input_file > output_file

#####################################################################

push @slurmjob, '
early()
{
 echo \' \'
 echo \' ############ WARNING:  EARLY TERMINATION ############# \'
 echo \' \'
}
';

##################################################
#                                                #
#   Staging in, running the job, and staging out #
#   were specified above as functions.  Now      #
#   call these functions to perform the actual   #
#   file transfers and program execution.        #
#                                                #
##################################################

my $epilog = join '', @slurmjob;

###### use loop to submit whole @jobarray ########------------
foreach my $job (0..($#jobarray - 1)){
  runserialjob($job);
}
## final job
runserialjob($#jobarray);


#### -------------------------------------------------------------------
sub runserialjob{
    my $j = $_[0];
    my $slurmjob = '';
    $slurmjob .= $directives;
    $slurmjob .= $prolog;
    $slurmjob .= $jobarray[$j];
    $slurmjob .= $epilog;
    $slurmjob .= "exit\n";
    open QSUB, "> sub.sh" or die "Failed to write";
    printf QSUB "$slurmjob";
    close(QSUB) or die "Couldn't close QSUB";
    system "sbatch sub.sh\n";
}

