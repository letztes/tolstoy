#!/usr/bin/perl

use warnings;
use strict;

use feature 'say';

use Data::Dumper;
use File::Slurp;
use Template;

my $OUTPUT_PATH = '/var/www/tolstoy';

my $CHAPTERS_DIR = './01text/vol_10/01text';

my $TOC_FILENAME = 'index.htm';

opendir(my $dh, $CHAPTERS_DIR) || die $!;
my @CHAPTER_FILES = sort grep { /^[^\.]/ && -f "$CHAPTERS_DIR/$_" } readdir($dh);
closedir($dh);

my %NEIGHBOURS_FOR_FILE = get_neighbours();
my %TITLE_FOR_FILE;

sub get_neighbours {
    
    # Set $TOC_FILENAME as default for cases like first or last page
    my %neighbours_for_file = ($CHAPTER_FILES[0] => {'previous' => $TOC_FILENAME,
                                                     'next' => $CHAPTER_FILES[1],
                                                    },
                               $CHAPTER_FILES[-1] => {'previous' => $CHAPTER_FILES[-2],
                                                     'next' => $TOC_FILENAME,
                                                    },
                               );
    
    for (my $i = 1; $i <= $#CHAPTER_FILES-1; $i++) {
        $neighbours_for_file{$CHAPTER_FILES[$i]} = {'previous' => $CHAPTER_FILES[$i-1],
                                                    'next' => $CHAPTER_FILES[$i+1],
                                                    };
    }
    return %neighbours_for_file;
}
    

sub inner_page_navigation {
    my $anchor_iterator = shift;
    
    # Default for the first page
    my $anchor_back = $anchor_iterator;
    $anchor_back = $anchor_iterator-1 if $anchor_iterator > 1;
    
    my $anchor_forth = $anchor_iterator+1;
    
    my $navigation = <<"END";
            
        </p>
        <table style="width:100%;text-align:center">
            <tr>
                <td style="width:33%;background-color:#ddd;display:block;float:left">
                    <a href="#$anchor_back">
                        <div style="width:100%;height:100%">back</div>
                    </a>
                </td>
                <td style="width:33%;background-color:#eee;display:block;float:left">
                    <a href="$TOC_FILENAME">
                        <div style="width:100%;height:100%">toc</div>
                    </a>
                </td>
                <td style="width:33%;background-color:#ddd;display:block;float:left">
                    <a href="#$anchor_forth">
                        <div style="width:100%;height:100%">forth</div>
                    </a>
                </td>
            </tr>
        </table>
        <p>

END
     
    return $navigation;
}

sub between_pages_navigation {
    my $filename = shift;
    
    my $navigation = <<"END";
            
        <table style="width:100%;text-align:center">
            <tr>
                <td style="width:33%;background-color:#ddd;display:block;float:left">
                    <a href="$NEIGHBOURS_FOR_FILE{$filename}{'previous'}">
                        <div style="width:100%;height:100%">previous story</div>
                    </a>
                </td>
                <td style="width:33%;background-color:#eee;display:block;float:left">
                    <a href="$TOC_FILENAME">
                        <div style="width:100%;height:100%">toc</div>
                    </a>
                </td>
                <td style="width:33%;background-color:#ddd;display:block;float:left">
                    <a href="$NEIGHBOURS_FOR_FILE{$filename}{'next'}">
                        <div style="width:100%;height:100%">next story</div>
                    </a>
                </td>
            </tr>
        </table>

END
     
    return $navigation;
}

sub make_toc {
    my %TITLE_FOR_FILE = @_;
    
    # Prepend the number from filename to the chapter name
    my %title_for_file_with_numbers = map { $_ =~ /([1-9]\d+)/; $_ => "$1. $TITLE_FOR_FILE{$_}" } keys %TITLE_FOR_FILE;
    
    my @chapter_links = map { qq[<tr><td><a href="$_">$title_for_file_with_numbers{$_}</a></td></tr>] } sort keys %title_for_file_with_numbers;
    
    my $links_string = join("\n", '<table>', @chapter_links, '</table>');
    
    print_html({'filename' => $TOC_FILENAME, 'title' => 'Ë.Í.Òîëñòîé. Ñîáð. ñî÷. â 22 ò. ', 'subtitle' => 'Ò.10. Ñîäåðæàíèå', 'paragraphs_string' => $links_string});
}

sub print_html {
    my ($arg_href) = @_;
    my $title = $arg_href->{'title'} || '';
    my $subtitle = $arg_href->{'subtitle'} || '';
    my $paragraphs_string = $arg_href->{'paragraphs_string'} or die 'Argument paragraphs_string is mandatory.' . Dumper $arg_href;
    my $between_pages_navigation = $arg_href->{'between_pages_navigation'} || '';
    
    my $template_filename = 'tolstoy.tt';
    
    my $output_filename = $arg_href->{'filename'} or die 'Argument filename is mandatory.';
    
    my $vars_href = {'title' => $title, 'subtitle' => $subtitle, 'paragraphs' => $paragraphs_string, 'between_pages_navigation' => $between_pages_navigation,};
    
    my $template = Template->new({OUTPUT_PATH => $OUTPUT_PATH});
    $template->process($template_filename, $vars_href, $output_filename);
    
    return;
}

sub main {
    foreach my $chapter_file (@CHAPTER_FILES) {
        my $title;
        my $subtitle;
        my @paragraphs;
        
        foreach my $line (read_file( "$CHAPTERS_DIR/$chapter_file" )) {
            $title = $1 if $line =~ /<h1>(.+)<?/;
            $subtitle = $1 if $line =~ /class="subhead"><i>(.+)<\/i>/;
            push(@paragraphs, $1) if $line =~ /<p id="p.+">(.+)</;
            $paragraphs[$#paragraphs] .= $1 if $line =~ /<p class="continuation">(.+)</;
            push(@paragraphs, $1) if $line =~ /<span class="line" id="L\d+">(.+)<\/span>/;
        }
        
        $TITLE_FOR_FILE{$chapter_file} = $title;
        
        @paragraphs = map { "<p>$_</p>" } @paragraphs;
        my $paragraphs_concatted_string = join(' ', @paragraphs);
        
        # Insert after each 650 characters a navigation bar. Regardless
        # the paragraph boundaries.
        my $max_characters = 300;
        my $characters_amount;
        my $anchor_iterator = 1;
        my $paragraphs_concatted_string_with_navigation;
        my @words = split(' ', $paragraphs_concatted_string);
        foreach my $word (@words) {
            $paragraphs_concatted_string_with_navigation .= "$word ";
            $characters_amount += length($word);
            if ($characters_amount >= $max_characters) {
                $paragraphs_concatted_string_with_navigation .= inner_page_navigation($anchor_iterator);
                $paragraphs_concatted_string_with_navigation .= q[<span id="] .($anchor_iterator+1). q["></span>];
                $anchor_iterator++;
                $characters_amount = 0;
            }
        }
        
        my $between_pages_navigation = between_pages_navigation($chapter_file);
        
        print_html({'filename' => $chapter_file, 'title' => $title, 'subtitle' => $subtitle, 'paragraphs_string' => $paragraphs_concatted_string_with_navigation, 'between_pages_navigation' => $between_pages_navigation});
    }
    make_toc(%TITLE_FOR_FILE);
}

main();



