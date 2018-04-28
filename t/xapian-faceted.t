#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

BEGIN { $ENV{DBIX_CONFIG_DIR} = "t" };

use File::Spec::Functions qw/catfile catdir/;
use lib catdir(qw/t lib/);
use Text::Amuse::Compile::Utils qw/read_file write_file/;
use AmuseWiki::Tests qw/create_site/;
use AmuseWikiFarm::Schema;
use Test::More tests => 153;
use Data::Dumper::Concise;
use Path::Tiny;

my $builder = Test::More->builder;
binmode $builder->output,         ":encoding(utf-8)";
binmode $builder->failure_output, ":encoding(utf-8)";
binmode $builder->todo_output,    ":encoding(utf-8)";
binmode STDOUT, ":encoding(utf-8)";

my $site_id = '0facets0';
my $schema = AmuseWikiFarm::Schema->connect('amuse');
my $site = create_site($schema, $site_id);

$site->update({ secure_site => 0 });
$site->site_options->update_or_create({
                                       option_name => 'show_preview_when_deferred',
                                       option_value => 1,
                                      });
$site->site_options->update_or_create({
                                       option_name => 'automatic_teaser',
                                       option_value => 1,
                                      });

$site = $site->get_from_storage;

{
    my $file = path($site->repo_root, qw/t t1 test1.muse/);
    $file->parent->mkpath;
    my $muse = <<'MUSE';
#title First test
#topics kuća, snijeg, škola, peć
#authors pinkić palinić, kajo šempronijo
#pubdate 2013-12-25
#date -1993-
#lang en

** This is a book common

** Because it has sectioning

MUSE
    $file->spew_utf8($muse);
}

{
    my $file = path($site->repo_root, qw/t t1 test-19.muse/);
    $file->parent->mkpath;
    my $muse = <<'MUSE';
#title Gulliver's Travels
#pubdate 2030-12-25
#date 1726
#lang en

MUSE
    $file->spew_utf8($muse, path('t', 'test-repos', 'gulliver.txt')->slurp_utf8);
}



{
    my $file = path($site->repo_root, qw/t t2 test2.muse/);
    $file->parent->mkpath;
    my $muse = <<'MUSE';
#title Second test kuća
#topics kuća, snijeg, škola, peć, xkuća, xsnijeg, xškola, xpeć, hullo
#authors apinkić apalinić, akajo ašempronijo, pinkić palinić, kajo šempronijo, hey
#pubdate 2009-12-25
#lang en
#date -1559-

This is not a book common

This is an article

MUSE
    $file->spew_utf8($muse);
}

{
    my $file = path($site->repo_root, qw/t t3 test3.muse/);
    $file->parent->mkpath;
    my $muse = <<'MUSE';
#title Third test
#topics xkuća, xsnijeg, xškola, xpeć
#authors apinkić apalinić, akajo ašempronijo
#pubdate 2017-12-25
#date (2001)
#lang hr

This is a very long piece common

MUSE

    my $lorem = <<'LOREM';

Sed ut perspiciatis unde omnis iste natus error sit voluptatem
accusantium doloremque laudantium, totam rem aperiam, eaque ipsa
quae ab illo inventore veritatis et quasi architecto beatae vitae
dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit
aspernatur aut odit aut fugit, sed quia consequuntur magni dolores
eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam
est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci
velit, sed quia non numquam eius modi tempora incidunt ut labore
et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima
veniam, quis nostrum exercitationem ullam corporis suscipit
laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem
vel eum iure reprehenderit qui in ea voluptate velit esse quam
nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo
voluptas nulla pariatur


Što je Lorem Ipsum?

Lorem Ipsum je jednostavno probni tekst koji se koristi u tiskarskoj i
slovoslagarskoj industriji. Lorem Ipsum postoji kao industrijski
standard još od 16-og stoljeća, kada je nepoznati tiskar uzeo
tiskarsku galiju slova i posložio ih da bi napravio knjigu s uzorkom
tiska. Taj je tekst ne samo preživio pet stoljeća, već se i vinuo u
svijet elektronskog slovoslagarstva, ostajući u suštini nepromijenjen.
Postao je popularan tijekom 1960-ih s pojavom Letraset listova s
odlomcima Lorem Ipsum-a, a u skorije vrijeme sa software-om za stolno
izdavaštvo kao što je Aldus PageMaker koji također sadrži varijante
Lorem Ipsum-a. Zašto ga koristimo?

Odavno je uspostavljena činjenica da čitača ometa razumljivi tekst dok
gleda raspored elemenata na stranici. Smisao korištenja Lorem Ipsum-a
jest u tome što umjesto 'sadržaj ovjde, sadržaj ovjde' imamo normalni
raspored slova i riječi, pa čitač ima dojam da gleda tekst na
razumljivom jeziku. Mnogi programi za stolno izdavaštvo i uređivanje
web stranica danas koriste Lorem Ipsum kao zadani model teksta, i ako
potražite 'lorem ipsum' na Internetu, kao rezultat dobit ćete mnoge
stranice u izradi. Razne verzije razvile su se tijekom svih tih
godina, ponekad slučajno, ponekad namjerno (s dodatkom humora i
slično). LOREM

LOREM
    $file->spew_utf8($muse, $lorem x 20);
}

ok $site->xapian->index_deferred or  die;

$site->update_db_from_tree(sub { diag @_ });

{
    my $res = $site->xapian->faceted_search(query => "is");
    is $res->pager->total_entries, 4;
}

{
    my $sample = $site->titles->first;

    $sample->date('1759-');
    is $sample->date_decade, 1750;

    $sample->date('-1800');
    is $sample->date_decade, 1800;

    $sample->date('-1799-');
    is $sample->date_decade, 1790;

    $sample->date('(2000-2001)');
    is $sample->date_decade, 2000;
    
    $sample->date('(1999-2001)');
    is $sample->date_decade, 1990;

    $sample->date('(1991)');
    is $sample->date_decade, 1990;

    $sample->text_size(2000 * 3000);
    is $sample->page_range, '+1000';

    $sample->text_size(2000 * 600);
    is $sample->page_range, '500-1000';

    $sample->text_size(500);
    is $sample->page_range, '1-5';
}

{
    my $res = $site->xapian->faceted_search(query => q{year:"2001"});
    is $res->pager->total_entries, 1;
    is $res->matches->[0]->{pagedata}->{uri}, 'test3';
}

{
    foreach my $title ($site->titles) {
        ok $title->page_range;
        diag $title->page_range;
    }
}

{
    my $res = $site->xapian->faceted_search(query => q{title:"Third Test"});
    is $res->pager->total_entries, 1;
    is $res->matches->[0]->{pagedata}->{uri}, 'test3';
}

{
    my $res = $site->xapian->faceted_search(query => q{title:"second test kuća"});
    is $res->pager->total_entries, 1;
    is $res->matches->[0]->{pagedata}->{uri}, 'test2';
}

{
    my $res = $site->xapian->faceted_search(query => q{title:"kuća"});
    is $res->pager->total_entries, 1;
    is $res->matches->[0]->{pagedata}->{uri}, 'test2';
}

{
    my $res = $site->xapian->faceted_search(query => q{"Taj je tekst" AND "ne samo preživio"});
    is $res->pager->total_entries, 1;
    is $res->matches->[0]->{pagedata}->{uri}, 'test3';
}

{
    my $res = $site->xapian->faceted_search(query => "is", filter_date => '1990');
    is $res->pager->total_entries, 1;
}

{
    my $res = $site->xapian->faceted_search(query => "is",
                                            filter_topic => $site->categories
                                            ->by_type_and_uri('topic', 'skola')->full_uri);
    is $res->pager->total_entries, 2 or diag Dumper($res);
}


{
    my $res = $site->xapian->faceted_search(query => "is",
                                            filter_author => $site->categories
                                            ->by_type_and_uri('author', 'pinkic-palinic')->full_uri);
    is $res->pager->total_entries, 2 or diag Dumper($res);
}


{
    my $res = $site->xapian->faceted_search(query => "is", filter_qualification => 'article');
    is $res->pager->total_entries, 2 or diag Dumper($res);
}

{
    my $res = $site->xapian->faceted_search(query => "is", filter_qualification => 'book');
    is $res->pager->total_entries, 2 or diag Dumper($res);
}


{
    my $res = $site->xapian->faceted_search(query => "is", filter_pages => '1-5');
    is $res->pager->total_entries, 2 or diag Dumper($res);
}


{
    my $res = $site->xapian->faceted_search(query => "is", filter_pubdate => '2013');
    is $res->pager->total_entries, 1 or diag Dumper($res);
}

{
    my $res = $site->xapian->faceted_search;
    is $res->pager->total_entries, 4;
}

my %SORTINGS = $site->xapian->sortings;
foreach my $sort_by (keys %SORTINGS) {
    my $res = $site->xapian->faceted_search(sort => $sort_by . '_asc');
    is $res->pager->total_entries, 4;
    my $res1 = $site->xapian->faceted_search(sort => $sort_by . '_desc');
    is $res1->pager->total_entries, 4;
    is $res1->matches->[0]->{pagename}, $res->matches->[-1]->{pagename}, "$sort_by OK";
}

{
    my $res = $site->xapian->faceted_search(filter_pubdate => [qw/2013 2017/],
                                            filter_date => '2000');
    is $res->pager->total_entries, 1;
}

{
    my $res = $site->xapian->faceted_search(filter_pubdate => [qw/2013 2017/],
                                            filter_date => '1550');
    is $res->pager->total_entries, 0;
}

{
    my $res = $site->xapian->faceted_search(filter_pubdate => '2009',
                                            filter_date => '1550');
    is $res->pager->total_entries, 1;
}


{
    my $res = $site->xapian->faceted_search(filter_date => '1550');
    is $res->pager->total_entries, 1;
}

{
    my $res = $site->xapian->faceted_search(site => $site,
                                            lh => $site->localizer,
                                            locale => 'hr',
                                            query => '',
                                           );
    ok($res->authors);
    ok($res->topics);
    ok($res->dates);
    ok($res->pubdates);
    ok($res->num_pages);
    ok($res->text_types);
    # diag Dumper($res);
    ok $res->texts;
    diag Dumper([ map { $_->full_uri } @{$res->texts} ]);
    diag Dumper($res->facet_tokens);
    foreach my $f (@{$res->facet_tokens}) {
        ok scalar(@{$f->{facets}});
        ok $f->{name};
        ok $f->{label};
        foreach my $v (@{$f->{facets}}) {
            ok $v->{value};
            ok $v->{count};
            ok $v->{label};
        }
    }
}

{
    my $res = $site->xapian->faceted_search(lh => $site->localizer,
                                            site => $site,
                                            locale => 'hr',
                                            query => 'nepoznati tiskar'
                                           );
    is $res->pager->total_entries, 1;
    is $res->json_output->[0]->{url}, "http://0facets0.amusewiki.org/library/test3";
}

{
    my $res = $site->xapian->faceted_search(query => 'inform the captain',
                                            site => $site,
                                           );
    is $res->pager->total_entries, 1;
    is $res->json_output->[0]->{url}, "http://0facets0.amusewiki.org/library/test-19";
}