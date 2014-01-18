#!/usr/bin/env perl
#
# Scanner tool for science experiments
#
# Jeff Squyres (c) 2013-2014
#

my $msg_dir = "/tmp/experiment-messages";
if (! -d $msg_dir) {
    system("mkdir $msg_dir; chmod 777 $msg_dir");
}

# Start the toutput    
print "Content-type: text/html\n\n";

print "<html><body>\n";

# Do we have any output to show?
opendir(my $dh, $msg_dir) || die "can't opendir $msf_dir: $!";
my @files_to_read = sort(grep { /^from-scanner/ && -f "$msg_dir/$_" } readdir($dh));
closedir $dh;

print "<p>Output from scanner:\n
<pre>\n";
foreach my $file (@files_to_read) {
    my $filename = "$msg_dir/$file";
    open(FH, $filename);
    my $message;
    $message .= $_
	while(<FH>);
    close(FH);
    unlink($filename);
    print $message;
}
print("</pre>\n<p>End of output from scanner\n");
print("</body></html>\n");

exit(0);
