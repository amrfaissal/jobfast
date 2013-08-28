#!/usr/bin/perl
#
# JobFast --version 1.0.1
# by: about.me/faissal_elamraoui
#

use strict;
use warnings;
use Net::SMTP::SSL;
use Term::ProgressBar;
use MIME::Base64;
use File::Spec;
use LWP::MediaTypes;
use Time::HiRes qw/usleep gettimeofday tv_interval/;



sub send_application {
    my $to = shift (@_);
    my $subject = shift (@_);
    my $body = shift (@_);
    my @attachments= @_;
    my $smtp;

    if (not $smtp = Net::SMTP::SSL->new(
            'mail.server.com',
            Port => 465,
            Debug => 0 )) {
        die "Couldn't connect to server\n";
    }

    # Authenticate
    # Feed the progress bar
    my $from = 'example@email.com';
    my $password = 'xxxxx';
    my $progress = Term::ProgressBar->new ({count => 22 , name => "[Sending]"});
    my $count = 1;
    $smtp->auth($from, $password) || die "Authentication failed!\n";
    $progress->update($count++);

    # Create arbitrary boundary text used to seperate
    # different parts of the message
    my ($bi, $bn, @bchrs);
    my $boundry = "";
    foreach $bn (48..57,65..90,97..122) {
        $bchrs[$bi++] = chr($bn);
    }
    foreach $bn (0..20) {
        $boundry .= $bchrs[rand($bi)];
    }

    # Send the header
    $smtp->mail($from);
    $progress->update($count++);
    my @recipients = split(/,/ , $to);
    $smtp->to($_ . "\n") foreach (@recipients);
    $progress->update($count++);
    $smtp->data();
    $progress->update($count++);
    $smtp->datasend("From: " . $from . "\n");
    $progress->update($count++);
    $smtp->datasend("To: " . $to . "\n");
    $progress->update($count++);
    $smtp->datasend("Subject: " . $subject . "\n");
    $progress->update($count++);
    $smtp->datasend("MIME-Version: 1.0\n");
    $progress->update($count++);
    $smtp->datasend("Content-Type: multipart/mixed; BOUNDARY=\"$boundry\"\n");
    $progress->update($count++);

    # Send the body
    $smtp->datasend("\n--$boundry\n");
    $progress->update($count++);
    $smtp->datasend("Content-Type: text/plain\n");
    $progress->update($count++);
    $smtp->datasend($body . "\n\n");
    $progress->update($count++);

    # Send attachments
    foreach my $file (@attachments) {
        unless (-f $file) {
            die "Unable to find attachment file $file\n";
            next;
        }
        my($bytesread, $buffer, $data, $total);
        open(FH, "$file") || die "Failed to open $file\n";
        binmode(FH);
        while (($bytesread = sysread(FH, $buffer, 1024)) == 1024) {
            $total += $bytesread;
            $data .= $buffer;
        }
        if ($bytesread) {
            $data .= $buffer;
            $total += $bytesread;
        }
        close FH;
        # Get the file name without its directory
        my ($volume, $dir, $fileName) = File::Spec->splitpath($file);
        # Try and guess the MIME type from the file extension so
        # that the email client doesn't have to
        my $contentType = guess_media_type($file);
        if ($data) {
            $smtp->datasend("--$boundry\n");
            $progress->update($count++);
            $smtp->datasend("Content-Type: $contentType; name=\"$fileName\"\n");
            $progress->update($count++);
            $smtp->datasend("Content-Transfer-Encoding: base64\n");
            $progress->update($count++);
            $smtp->datasend("Content-Disposition: attachment; =filename=\"$fileName\"\n\n");
            $progress->update($count++);
            $smtp->datasend(encode_base64($data));
            $progress->update($count++);
            $smtp->datasend("--$boundry\n");
            $progress->update($count++);
        }
    }

    # Quit
    $smtp->datasend("\n--$boundry--\n"); # send boundary end message
    $progress->update($count++);
    $smtp->datasend("\n");
    $progress->update($count++);
    $smtp->dataend();
    $progress->update($count++);
    $smtp->quit;
    $progress->update($count++);
}

# Load Templates
sub _load_tmpl {
    # Template path
    my $path = shift;
    # Load data from template
    my @data;
    open(FH , $path) or die "Couldn't open template";
    @data = <FH>;
    close FH;
    return "@data";
}

# SEND YOUR APPLICATION
&send_application("email@example.com", "Job application",
            &_load_tmpl('/your/home/Templates/msg.txt'),
            '/your/home/Templates/CV.pdf'
    );
