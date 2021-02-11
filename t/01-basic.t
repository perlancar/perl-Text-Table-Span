#!perl

use 5.010001;
use strict;
use warnings;
use Test::More 0.98;

use Text::Table::Span qw(generate_table);

my $rows;

$rows = [
    [{text=>"header1",colspan=>2},"header2","header3"],
    ["cell0,1","cell1,1",{text=>"cell2-3,1L1\nL2",colspan=>2}],
    [{text=>"cell0-1,2L1\nL2\nL3",colspan=>2},{text=>"cell2-3,2",colspan=>2}],
    [{text=>"cell0-3,3",colspan=>4}],
] if 0;

$rows = [
    [{text=>"A",colspan=>2},"C","D"],
    [{text=>"a1", bottom_border=>1}, "b1",{text=>"c-d1 L1\nL2\nL3",colspan=>2}],
    [{text=>"a-b2 L1\nL2\nL3",colspan=>2},{text=>"c-d2",colspan=>2}],
    [{text=>"a3-5 L1\nL2\nL3\nL4", rowspan=>3, bottom_border=>1}, {text=>"b-d3",colspan=>3}, ],
    #[{text=>"a-c3",colspan=>3, bottom_border=>1}, {text=>"d3-5 L1\nL2\nL3\nL4", rowspan=>3, bottom_border=>1}],
    [{text=>"a4",colspan=>1},"b4","c4"],
    [{text=>"a5",colspan=>1},"b5","c5"],
] if 0;

$rows = [
    ["age","height","height z-score", "weight","weight z-score"],
    ["1y0m","50","-1.1", "11","0.2"],
    ["1y0m","50","-1.1", "11","0.2"],
    ["1y0m","50","-1.1", "11","0.2"],
    ["1y0m","50","-1.1", "11","0.2"],
    ["1y0m","50","-1.1", "11","0.2"],
    ["1y0m","50","-1.1", "11","0.2"],
    ["1y0m","50","-1.1", "11","0.2"],
    ["1y0m","50","-1.1", "11","0.2"],
    ["1y0m","50","-1.1", "11","0.2"],
    [{text=>"average", top_border=>1}, {colspan=>2, text=>"87"}, {colspan=>2, text=>"87"}],
] if 0;

$rows = [
    ["A0","B0"],
    [{text=>"A1-2",rowspan=>2} ,"B1"],
    ["B2"],
] if 0;

$rows = [
    ["A0","B0"],
    ["A1",{text=>"B1-2",rowspan=>2}],
    ["A2"],
] if 0;

$rows = [
    ["A0","B0","C0"],
    ["A1",{text=>"BC12",colspan=>2, rowspan=>2}],
    ["A2"],
] if 0;

$rows = [
    ["A0","B0","C0"],
    [{text=>"AB12 L1\nL2\nL3",colspan=>2, rowspan=>2, bottom_border=>1},"C1"],
    ["C2"],
    ["A3","B3","C3"],
] if 1;

#use DD; dd $rows;
binmode STDOUT, "utf8";
print generate_table(
    rows => $rows,
    #border_style => "Test::Labeled",
    border_style => "ASCII::SingleLine",
    #border_style => "UTF8::SingleLineBoldHeader",
    #border_style => "ASCII::None",

    #row_separator=>1,

    header_row => 1,
    #header_row => 0,
) if 1;


done_testing;
