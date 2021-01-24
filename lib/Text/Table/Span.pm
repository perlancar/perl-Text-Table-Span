package Text::Table::Span;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;

use List::AllUtils qw(first firstidx max);

use Exporter qw(import);
our @EXPORT_OK = qw/ generate_table /;

# consts
sub IDX_SCELL_ORIG_ROWNUM() {0}
sub IDX_SCELL_ORIG_COLNUM() {1}
sub IDX_SCELL_ROWSPAN()     {2}
sub IDX_SCELL_COLSPAN()     {3}

sub generate_table {
    my %args = @_;
    my $rows = $args{rows} or die "Please specify rows";
    my $cell_styles = $args{cell_styles} // [];

    my $scells = []; # [ [[$orig_rowidx,$orig_,$rowspan,$colspan], ...], [[...], ...], ... ]
  CONSTRUCT_SCELLS: {
        # 1. the first step is to construct a 2D array we call "scells", which
        # is the small boxes/cells we will draw later. a table cell with
        # colspan=2 will become 2 scells. an m-row x n-column table will become
        # M-row x N-column scells, where M>=m, N>=n.

        my $rownum = -1;
        for my $row (@$rows) {
            $rownum++;
            my $colnum = -1;
            $scells->[$rownum] //= [];
            my $scell_colnum = firstidx {!defined} @{ $scells->[$rownum] };
            $scell_colnum = 0 if $scell_colnum == -1;

            for my $cell (@$row) {
                $colnum++;
                my $text;

                my $rowspan = 1;
                my $colspan = 1;
                if (ref $cell eq 'HASH') {
                    $text = $cell->{text};
                    $rowspan = $cell->{rowspan} if $cell->{rowspan};
                    $colspan = $cell->{colspan} if $cell->{colspan};
                } else {
                    $text = $cell;
                    my $el;
                    $el = first {$_->[0] == $rownum && $_->[1] == $colnum && $_->[2]{rowspan}} @$cell_styles;
                    $rowspan = $el->[2]{rowspan} if $el;
                    $el = first {$_->[0] == $rownum && $_->[1] == $colnum && $_->[2]{colspan}} @$cell_styles;
                    $colspan = $el->[2]{colspan} if $el;
                }

                for my $rs (1..$rowspan) {
                    for my $cs (1..$colspan) {
                        if ($rs == 1 && $cs == 1) {
                            $scells->[$rownum][$scell_colnum][IDX_SCELL_ORIG_ROWNUM] = $rownum;
                            $scells->[$rownum][$scell_colnum][IDX_SCELL_ORIG_COLNUM] = $colnum;
                            $scells->[$rownum][$scell_colnum][IDX_SCELL_ROWSPAN]     = $rowspan;
                            $scells->[$rownum][$scell_colnum][IDX_SCELL_COLSPAN]     = $colspan;
                            #$scells->[$rownum][$scell_colnum][4]     = $text; # testing
                        } else {
                            $scells->[$rownum+$rs-1][$scell_colnum+$cs-1] = [];
                        }
                        #use Data::Dump::Color; dd $scells; say ''; # test
                    }
                }

                $scell_colnum += $colspan;
                $scell_colnum++ while defined $scells->[$rownum][$scell_colnum];
            } # for a row
        } # for rows
    } # CONSTRUCT_SCELLS
    #use Data::Dump::Color; dd $scells; # test

  OPTIMIZE_SCELLS: {
        # TODO

        # 2. we reduce extraneous columns and rows if there are colspan that are
        # too many. for example, if all cells in column 1 has colspan=2 (or one
        # row has colspan=2 and another row has colspan=3), we might as remove 1
        # column because the extra column span doesn't have any content. same
        # case for extraneous row spans.
    } # OPTIMIZE_SCELLS

  DETERMINE_SIZE_OF_EACH_SCELL_COLUMN_AND_ROW: {
    } # DETERMINE_SIZE_OF_EACH_SCELL_COLUMN_AND_ROW

  DRAW_SCELLS: {
    } # DRAW_SCELLS

}

# Back-compat: 'table' is an alias for 'generate_table', but isn't exported
{
    no warnings 'once';
    *table = \&generate_table;
}

1;
# ABSTRACT: Text::Table::Tiny + support for column/row spans

=for Pod::Coverage ^(.+)$

=head1 SYNOPSIS

You can either specify column & row spans in the cells themselves, using
hashrefs:

 use Text::Table::Span qw/generate_table/;

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
      {text=>"four winners (Outstanding Program Achievements in Entertainment)", colspan=>3},
      {text=>"five winners (Outstanding Program Achievements in Entertainment)", colspan=>4}],

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
     #border_style => 'ASCII::SingleLineDoubleAfterHeader', # module in BorderStyle::* namespace, without the prefix. default is ASCII::SingleLineDoubleAfterHeader
 );

Or, you can also use the C<cell_styles> option:

 use Text::Table::Span qw/generate_table/;

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
      "The Defenders (CBS)",,
      "The Garry Moore Show (CBS)",
      "E. G. Marshall, The Defenders (CBS)",
      "Shirley Booth, Hazel (NBC)"],

     # second data row
     [1963,
      "The Dick Van Dyke Show (CBS)",
      "The Andy Williams Show (NBC)"],

     # third data row
     [1964,
      "The Danny Kaye Show (CBS)"],

     # fourth data row
     [1965,
      "four winners (Outstanding Program Achievements in Entertainment)",
      "five winners (Outstanding Program Achievements in Entertainment)"],

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
     #border_style => 'ASCII::SingleLineDoubleAfterHeader', # module in BorderStyle::* namespace, without the prefix. default is ASCII::SingleLineDoubleAfterHeader
     cell_styles => [
         # rownum (0-based int), colnum (0-based int), styles (hashref)
         [1, 2, {rowspan=>3}],
         [1, 4, {rowspan=>2, colspan=>2}],
         [1, 5, {rowspan=>2, colspan=>2}],
         [2, 1, {rowspan=>2}],
         [3, 2, {colspan=>2}],
         [3, 3, {colspan=>2}],
         [4, 1, {colspan=>3}],
         [4, 2, {colspan=>4}],
     ],
 );


=head1 DESCRIPTION

This module is like L<Text::Table::Tiny> (0.04) with added support for column/row
spans, and border style.


=head1 FUNCTIONS

=head2 generate_table


=head1 SEE ALSO

L<Text::Table::TinyBorderStyle>

HTML &lt;TABLE&gt; element,
L<https://www.w3.org/TR/2014/REC-html5-20141028/tabular-data.html>,
L<https://www.w3.org/html/wiki/Elements/table>

=cut
