use strict;
use warnings;

use Tk;
use Tk::ProgressBar;
use LWP::UserAgent;
use LWP::Simple;
use HTTP::Request;
use HTTP::Response;
use HTML::SimpleLinkExtor;
use File::Basename;

my ($domain, $lab, $box, $lab2, $box2, $max_links_count, $checked_links_count, $max_files_count, $found_files_count, $sum_files_size);
$max_links_count = 150; $checked_links_count = 0;
$max_files_count = 100, $found_files_count = 0;
$sum_files_size = 0;

my (@checked_urls, @found_files);

sub main
{
    my $bg_color = '#b1bcce';
    my $bg_color2 = '#ebcfb9';
    my $text_color = '#261212';
    my $text_font = 'Calibri 15';

    my $main_widget = MainWindow->new(-bg => $bg_color);
    $main_widget->title('Find pdf, doc, docx, xls, xlsx, ppt, pptx');
    $main_widget->geometry('800x500');

    my $frame1 = $main_widget->Frame(-bg => $bg_color);
    my $label1 = $frame1->Label(-text => "server address: ", -bg => $bg_color, -fg => $text_color, -font => $text_font)->pack(-side => 'left');
    my $entry1 = $frame1->Entry(-width => 50, -text => 'http://', -bg => $bg_color2, -fg => $text_color, -font => $text_font)->pack(-side => 'right');
    $frame1->pack(-fill => 'x');
    
    my $frame2 = $main_widget->Frame(-bg => $bg_color);
    my $label2 = $frame2->Label(-text => "max links count: ", -bg => $bg_color, -fg => $text_color, -font => $text_font)->pack(-side => 'left');
    my $entry2 = $frame2->Entry(-width => 5, -justify  => 'right', -text => \$max_links_count, -bg => $bg_color2, -fg => $text_color, -font => $text_font)->pack(-side => 'right');
    $frame2->pack(-fill => 'x');

    my $frame3 = $main_widget->Frame(-bg => $bg_color);
    my $label3 = $frame3->Label(-text => "max files count: ", -bg => $bg_color, -fg => $text_color, -font => $text_font)->pack(-side => 'left');
    my $entry3 = $frame3->Entry(-width => 5, -justify  => 'right', -text => \$max_files_count, -bg => $bg_color2, -fg => $text_color, -font => $text_font)->pack(-side => 'right');
    $frame3->pack(-fill => 'x');

    my $frame4 = $main_widget->Frame(-bg => $bg_color);
    $lab = $frame4->Label(-text => 'Found files', -bg => $bg_color, -fg => $text_color, -font => $text_font);
    $box = $frame4->Listbox(-relief => 'sunken', -bg => $bg_color2, -fg => $text_color, -font => $text_font, -height => 5, -width => 1);
    my $scroll = $frame4->Scrollbar(-command => ['yview', $box], -bg => $bg_color2, -troughcolor => $text_color);
    $box->configure(-yscrollcommand => ['set', $scroll]);
    $lab->pack(-side => 'top');
    $box->pack(-side => 'left', -fill => 'both', -expand => 1);
    $scroll->pack(-side => 'right', -fill => 'both');
    $frame4->pack(-side => 'bottom', -fill => 'both', -expand => 1);

    my $frame41 = $main_widget->Frame(-bg => $bg_color);
    $lab2 = $frame41->Label(-text => 'Checked links', -bg => $bg_color, -fg => $text_color, -font => $text_font);
    $box2 = $frame41->Listbox(-relief => 'sunken', -bg => $bg_color2, -fg => $text_color, -font => $text_font, -height => 5, -width => 1);
    my $scroll2 = $frame41->Scrollbar(-command => ['yview', $box2], -bg => $bg_color2, -troughcolor => $text_color);
    $box2->configure(-yscrollcommand => ['set', $scroll2]);
    $lab2->pack(-side => 'top');
    $box2->pack(-side => 'left', -fill => 'both', -expand => 1);
    $scroll2->pack(-side => 'right', -fill => 'both');
    $frame41->pack(-side => 'bottom', -fill => 'both', -expand => 1);

    my $frame5= $main_widget->Frame(-bg => $bg_color);
    my $button = $frame5->Button(-text => 'Find files', -bg => $bg_color2, -fg => $text_color, -font => $text_font,
                                 -command => sub{count_files($entry1->get)})->pack;
    $frame5->pack(-expand => 1);

    MainLoop;
}

sub count_files
{
    my ($url) = @_;

    $domain = $url;
    $box->delete(0, $found_files_count - 1);
    $box2->delete(0, $checked_links_count - 1);

    $checked_links_count = 0;
    $found_files_count = 0;
    $sum_files_size = 0;

    @checked_urls = ();
    @found_files = ();
    
    check_url($url);

    $lab->configure(-text => "Found $found_files_count files (summary size = ". $sum_files_size/1024 ." KB)");
    $lab2->configure(-text => "Checked $checked_links_count links");
    print("finished!\n");
}

sub check_url
{
    if ($checked_links_count >= $max_links_count || $found_files_count >= $max_files_count) { return; }

    my ($url) = @_;

    print("link № ". ($checked_links_count + 1) ." - $url\n");
    $box2->insert('end', "link ". ($checked_links_count + 1) ." - $url");

    my $user_agent = LWP::UserAgent->new;
    my $request = HTTP::Request->new('GET', $url);
    my $response = $user_agent->request($request);
    my $content = $response->content();

    my $e = HTML::SimpleLinkExtor->new();
    $e->parse($content);
    my @links = $e->a;

    check_url_for_documents($url);
    $checked_links_count += 1;

    foreach (@links)
    {
        if (index($_, '/') == 0)
        {
            my $inner_link = $domain.$_;
            my $modified_link = $inner_link =~ s/\?/question_mark/r;

            if (!grep(/^$modified_link$/, @checked_urls))
            {
                push @checked_urls, $modified_link;
                check_url($inner_link);
            }
        }
    }
}

sub check_url_for_documents
{
    my ($url) = @_;

    my $user_agent = LWP::UserAgent->new;
    my $request = HTTP::Request->new('GET', $url);
    my $response = $user_agent->request($request);
    my $content = $response->content();

    my $e = HTML::SimpleLinkExtor->new();
    $e->parse($content);
    my @links = $e->a;

    foreach my $lnk (@links)
    {
        if ($found_files_count >= $max_files_count) { last; }

        if ($lnk =~ m/\.(pdf|doc|docx|xls|xlsx|ppt|pptx)$/ && index($lnk, '/') == 0)
        {
            my $doc_name = $domain.$lnk;
            my $short_doc_name = basename($doc_name);

            if (!grep(/^$doc_name$/, @found_files))
            {
                push @found_files, $doc_name;
                print("\tDocument №". ($found_files_count + 1) ." $doc_name\n");

                $user_agent = LWP::UserAgent->new;
                $request = HTTP::Request->new(GET => $doc_name);
                $response = $user_agent->request($request);
                my $headers = $response->headers();
                my $size = $headers->header('Content-Length');
                if (! $size)
                {
                    getstore($doc_name, $short_doc_name);
                    $size = -s $short_doc_name;
                    unlink($short_doc_name);
                }

                $box->insert('end', $short_doc_name.' :  '.$size.' bytes, '.$size/1024 .' KB');
                $found_files_count += 1;
                $sum_files_size += $size;
            }
        }
    }
}

main();
