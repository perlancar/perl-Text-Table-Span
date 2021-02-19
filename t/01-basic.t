#!perl

use 5.010001;
use strict;
use utf8;
use warnings;
use Test::More 0.98;
#use Test::Differences;

use Text::Table::Span qw(generate_table);

#binmode STDOUT, ":encoding(UTF-8)";
#binmode STDERR, ":encoding(UTF-8)";
#binmode STDOUT, ":utf8";
#binmode STDERR, ":utf8";

my @tests = (
    {
        name => 'empty',
        rows => [],
        result => '',
    },

    {
        name => '1x1',
        rows => [["A"]],
        result => <<'_',
.---.
| A |
`---'
_
    },

    {
        name => '1x2',
        rows => [["A","BBB"]],
        result => <<'_',
.---+-----.
| A | BBB |
`---+-----'
_
    },

    {
        name => '2x1',
        rows => [["A"],["BBB"]],
        result => <<'_',
.-----.
| A   |
| BBB |
`-----'
_
    },

    {
        name => '2x2',
        rows => [["A","BBB"], ["CC","D"]],
        result => <<'_',
.----+-----.
| A  | BBB |
| CC | D   |
`----+-----'
_
    },

    {
        name => '2x2 + header_row',
        rows => [["A","BBB"], ["CC","D"]],
        args => {header_row=>1},
        result => <<'_',
.----+-----.
| A  | BBB |
+====+=====+
| CC | D   |
`----+-----'
_
    },

    {
        name => '3x2 + header_row',
        rows => [["A","BBB"], ["CC","D"], ["F","GG"]],
        args => {header_row=>1},
        result => <<'_',
.----+-----.
| A  | BBB |
+====+=====+
| CC | D   |
| F  | GG  |
`----+-----'
_
    },

    {
        name => '3x2 + header_row + separate_rows',
        rows => [["A","BBB"], ["CC","D"], ["F","GG"]],
        args => {header_row=>1, separate_rows=>1},
        result => <<'_',
.----+-----.
| A  | BBB |
+====+=====+
| CC | D   |
+----+-----+
| F  | GG  |
`----+-----'
_
    },

    {
        name => 'row attr: bottom_border',
        rows => [["A","BBB"], ["CC","D"], ["E","FF"],["G","H"]],
        args => {
            header_row=>1,
            row_attrs => [
                [2, {bottom_border=>1}],
            ],
        },
        result => <<'_',
.----+-----.
| A  | BBB |
+====+=====+
| CC | D   |
| E  | FF  |
+----+-----+
| G  | H   |
`----+-----'
_
    },

    {
        name => 'rowspan',
        rows => [
            ["A0","B0"],
            [{text=>"A12",rowspan=>2},"B1"],
            ["B2"],
            ["A3", {text=>"B34",rowspan=>2}],
            ["A4"],
        ],
        args => {header_row=>1, separate_rows=>1},
        result => <<'_',
.-----+-----.
| A0  | B0  |
+=====+=====+
| A12 | B1  |
|     +-----+
|     | B2  |
+-----+-----+
| A3  | B34 |
+-----+     |
| A4  |     |
`-----+-----'
_
    },

    {
        name => 'row height: rowspan longer',
        rows => [["A0","B0"], [{text=>"A1L1\nL2\nL3\nL4",rowspan=>2},"B1"], ["B2"]],
        args => {header_row=>1, separate_rows=>1},
        result => <<'_',
.------+----.
| A0   | B0 |
+======+====+
| A1L1 | B1 |
| L2   |    |
| L3   +----+
| L4   | B2 |
`------+----'
_
    },

    {
        name => 'colspan',
        rows => [
            [{text=>"AB0",colspan=>2},"C0"],
            ["A1", {text=>"BC1",colspan=>2}],
            [{text=>"AB2",colspan=>2},"C2"],
            ["A3","B3","C3"],
        ],
        args => {header_row=>1, separate_rows=>1},
        result => <<'_',
.---------+----.
| AB0     | C0 |
+====+====+====+
| A1 | BC1     |
+----+----+----+
| AB2     | C2 |
+----+----+----+
| A3 | B3 | C3 |
`----+----+----'
_
    },

    {
        name => 'rowcolspan 1',
        rows => [
            ["A0","B0","C0"],
            [{text=>"AB12L1\nL2\nL3",rowspan=>2,colspan=>2},"C1"],
            ["C2"],
            ["A3","B3","C3"],
        ],
        args => {header_row=>1, separate_rows=>1},
        result => <<'_',
.----+----+----.
| A0 | B0 | C0 |
+====+====+====+
| AB12L1  | C1 |
| L2      +----+
| L3      | C2 |
+----+----+----+
| A3 | B3 | C3 |
`----+----+----'
_
    },

    {
        name => 'rowcolspan 2',
        rows => [
            ["A0","B0","C0"],
            ["A1","B1","C1"],
            ["A2", {text=>"BC23L1\nL2\nL3",rowspan=>2,colspan=>2}],
            ["A3"],
        ],
        args => {header_row=>1, separate_rows=>1},
        result => <<'_',
.----+----+----.
| A0 | B0 | C0 |
+====+====+====+
| A1 | B1 | C1 |
+----+----+----+
| A2 | BC23L1  |
+----+ L2      |
| A3 | L3      |
`----+---------'
_
    },

    {
        name => 'align',
        rows => [
            [{text=>"A0", align=>'middle'},"B0","C0"], # cell attrs (hash cell)
            ["A1L1\nL2","B1","C1"],
            ["A2", {text=>"BC23L1\nL2\nL3",rowspan=>2,colspan=>2}],
            ["A3"],
        ],
        args => {
            align => 'right',
            header_row=>1,
            separate_rows=>1,
            row_attrs => [
                [1, {align=>'left'}], # row attrs
            ],
            col_attrs => [
                [1, {align=>'left'}], # col attrs
            ],
            cell_attrs => [
                [2, 0, {align=>'left'}],
            ],
        },
        result => <<'_',
.------+----+----.
|  A0  | B0 | C0 |
+======+====+====+
| A1L1 | B1 | C1 |
| L2   |    |    |
+------+----+----+
| A2   | BC23L1  |
+------+ L2      |
|   A3 | L3      |
`------+---------'
_
    },

);
my @include_tests = ("align"); # e.g. ("1x1")
my $border_style;# = "UTF8::SingleLineBoldHeader"; # force border style

for my $test (@tests) {
    if (@include_tests) {
        next unless grep { $_ eq $test->{name} } @include_tests;
    }
    subtest $test->{name} => sub {
        my $res = generate_table(
            rows => $test->{rows},
            ($test->{args} ? %{$test->{args}} : ()),
            ($border_style ? (border_style=>$border_style) : ()),
        );
        is($res, $test->{result}) or diag "expected:\n$test->{result}\nresult:\n$res";
    };
}

done_testing;
