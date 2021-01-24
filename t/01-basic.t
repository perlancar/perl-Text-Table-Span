#!perl

use 5.010001;
use strict;
use warnings;
use Test::More 0.98;

use Text::Table::Span qw(generate_table);

my $rows = [
    # header row
    ["Year",
     "Comedy",
     "Drama",
     "Variety",
     "Lead Comedy Actor",
     "Lead Drama Actor",
     "Lead Comedy Actress",
     "Lead Drama Actress"],
    # first data row
    [1962,
     "The Bob Newhart Show (NBC)",
     {text=>"The Defenders (CBS)", rowspan=>3},
     "The Garry Moore Show (CBS)",
     {text=>"E. G. Marshall, The Defenders (CBS)", rowspan=>2, colspan=>2},
     {text=>"Shirley Booth, Hazel (NBC)", rowspan=>2, colspan=>2}],
    # second data row
    [1963,
     {text=>"The Dick Van Dyke Show (CBS)", rowspan=>2},
     "The Andy Williams Show (NBC)"],
    # third data row
    [1964,
     "The Danny Kaye Show (CBS)",
     {text=>"Dick Van Dyke, The Dick Van Dyke Show (CBS)", colspan=>2},
     {text=>"Mary Tyler Moore, The Dick Van Dyke Show (CBS)", colspan=>2}],
    # fourth data row
    [1965,
     {text=>"four winners", colspan=>3},
     {text=>"five winners", colspan=>4}],
    # fifth data row
    [1966,
     "The Dick Van Dyke Show (CBS)",
     "The Fugitive (ABC)",
     "The Andy Williams Show (NBC)",
     "Dick Van Dyke, The Dick Van Dyke Show (CBS)",
     "Bill Cosby, I Spy (CBS)",
     "Mary Tyler Moore, The Dick Van Dyke Show (CBS)",
     "Barbara Stanwyck, The Big Valley (CBS)"],
];
print generate_table(
    rows => $rows,
    header_row => 1,
);

done_testing;
