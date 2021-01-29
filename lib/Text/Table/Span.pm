package Text::Table::Span;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;

use List::AllUtils qw(first firstidx max);
use String::Pad qw(pad);

use Exporter qw(import);
our @EXPORT_OK = qw/ generate_table /;

# consts
sub IDX_EXPTABLE_CELL_ORIG_ROWNUM() {0}
sub IDX_EXPTABLE_CELL_ORIG_COLNUM() {1}
sub IDX_EXPTABLE_CELL_ROWSPAN()     {2}
sub IDX_EXPTABLE_CELL_COLSPAN()     {3}
sub IDX_EXPTABLE_CELL_WIDTH()       {4} # visual width
sub IDX_EXPTABLE_CELL_HEIGHT()      {5} # visual height
sub IDX_EXPTABLE_CELL_TEXT()        {6}

sub _divide_int_to_n_ints {
    my ($int, $n) = @_;
    my $subtot = 0;
    my $int_subtot = 0;
    my $prev_int_subtot = 0;
    my @ints;
    for (1..$n) {
        $subtot += $int/$n;
        $int_subtot = sprintf "%.0f", $subtot;
        push @ints, $int_subtot - $prev_int_subtot;
        $prev_int_subtot = $int_subtot;
    }
    @ints;
}

sub _get_exptable_cell_lines {
    my ($exptable, $row_heights, $column_widths, $len_between_cols, $y, $x) = @_;

    my $cell = $exptable->[$y][$x];
    my $text = $cell->[IDX_EXPTABLE_CELL_TEXT];
    my $height = 0;
    my $width  = 0;
    for my $ic (1..$cell->[IDX_EXPTABLE_CELL_COLSPAN]) {
        $width += $column_widths->[$x+$ic-1];
        $width += $len_between_cols if $ic > 1;
    }
    for my $ir (1..$cell->[IDX_EXPTABLE_CELL_ROWSPAN]) {
        $height += $row_heights->[$ir];
    }

    my @lines;
    my @datalines = split /\R/, $text;
    for (1..@datalines) {
        push @lines, pad($datalines[$_-1], $width, 'right', ' ', 'truncate');
    }
    for (@datalines+1 .. $height) {
        push @lines, " " x $width;
    }
    \@lines;
}

sub generate_table {
    require Module::Load::Util;
    require Text::NonWideChar::Util;

    my %args = @_;
    my $rows = $args{rows} or die "Please specify rows";
    my $bs_name = $args{border_style} // 'ASCII::SingleLineDoubleAfterHeader';
    my $cell_styles = $args{cell_styles} // [];

    my $bs_obj = Module::Load::Util::instantiate_class_with_optional_args({ns_prefix=>"BorderStyle"}, $bs_name);

    my $len_between_cols = length(" " . $bs_obj->get_border_char(3, 1) . " ");

    my $exptable = []; # [ [[$orig_rowidx,$orig_colidx,$rowspan,$colspan,...], ...], [[...], ...], ... ]
    my $M = 0; # number of rows in the exptable
    my $N = 0; # number of columns in the exptable
  CONSTRUCT_EXPTABLE: {
        # 1. the first step is to construct a 2D array we call "exptable" (short
        # for expanded table), which is like the original table but with all the
        # spanning rows/columns split into the smaller boxes so it's easier to
        # draw later. for example, a table cell with colspan=2 will become 2
        # exptable cells. an m-row x n-column table will become M-row x N-column
        # exptable, where M>=m, N>=n.

        my $rownum = -1;
        for my $row (@$rows) {
            $rownum++;
            my $colnum = -1;
            $exptable->[$rownum] //= [];
            my $exptable_colnum = firstidx {!defined} @{ $exptable->[$rownum] };
            $exptable_colnum = 0 if $exptable_colnum == -1;

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

                my @widths;
                my @heights;
                for my $ir (1..$rowspan) {
                    for my $ic (1..$colspan) {
                        my $exptable_cell;
                        $exptable->[$rownum+$ir-1][$exptable_colnum+$ic-1] = $exptable_cell = [];

                        if ($ir == 1 && $ic == 1) {
                            $exptable_cell->[IDX_EXPTABLE_CELL_ORIG_ROWNUM] = $rownum;
                            $exptable_cell->[IDX_EXPTABLE_CELL_ORIG_COLNUM] = $colnum;
                            $exptable_cell->[IDX_EXPTABLE_CELL_ROWSPAN]     = $rowspan;
                            $exptable_cell->[IDX_EXPTABLE_CELL_COLSPAN]     = $colspan;
                            $exptable_cell->[IDX_EXPTABLE_CELL_TEXT]        = $text;
                            my $lh = Text::NonWideChar::Util::length_height($text);
                            @widths  = _divide_int_to_n_ints($lh->[0] + ($colspan-1)*$len_between_cols, $colspan);
                            @heights = _divide_int_to_n_ints($lh->[1], $rowspan);
                        }

                        $exptable_cell->[IDX_EXPTABLE_CELL_WIDTH]  = $widths[$ic-1];
                        $exptable_cell->[IDX_EXPTABLE_CELL_HEIGHT] = $heights[$ir-1];

                        #use Data::Dump::Color; dd $exptable_cell; say ''; # debug
                    }
                    $M = $rownum+$ir if $M < $rownum+$ir;
                }

                $exptable_colnum += $colspan;
                $exptable_colnum++ while defined $exptable->[$rownum][$exptable_colnum];
            } # for a row
            $N = $exptable_colnum if $N < $exptable_colnum;
        } # for rows
    } # CONSTRUCT_EXPTABLE
    use DD; dd $exptable; # debug
    #print "D: exptable size: $M x $N (HxW)\n"; # debug

  OPTIMIZE_EXPTABLE: {
        # TODO

        # 2. we reduce extraneous columns and rows if there are colspan that are
        # too many. for example, if all exptable cells in column 1 has colspan=2
        # (or one row has colspan=2 and another row has colspan=3), we might as
        # remove 1 column because the extra column span doesn't have any
        # content. same case for extraneous row spans.
        1;
    } # OPTIMIZE_EXPTABLE

    my $exptable_column_widths = []; # idx=exptable colnum
    my $exptable_row_heights   = []; # idx=exptable rownum
  DETERMINE_SIZE_OF_EACH_EXPTABLE_COLUMN_AND_ROW: {
        # 3. before we draw the exptable, we need to determine the width and
        # height of each exptable column and row.
        for my $ir (0..$M-1) {
            my $exptable_row = $exptable->[$ir];
            $exptable_row_heights->[$ir] = max(
                1, map {$_->[IDX_EXPTABLE_CELL_HEIGHT]} @$exptable_row);
        }

        for my $ic (0..$N-1) {
            $exptable_column_widths->[$ic] = max(
                1, map {$exptable->[$_][$ic] ? $exptable->[$_][$ic][IDX_EXPTABLE_CELL_WIDTH] : 0} 0..$M-1);
        }
    } # DETERMINE_SIZE_OF_EACH_EXPTABLE_COLUMN_AND_ROW
    use DD; print "column widths: "; dd $exptable_column_widths; # debug
    use DD; print "row heights: "; dd $exptable_row_heights; # debug

    # each elem is an arrayref containing characters to render a line of the
    # table: [$left_border_str, $exptable_cell_content1, $border_between_col,
    # $exptable_cell_content2, ...]. all will be joined together with "\n" to
    # form the final rendered table.
    my @buf;

  DRAW_EXPTABLE: {
        my $y = 0;
        for my $ir (0..$M-1) {

            # draw left border
            for my $i (1 .. $exptable_row_heights->[$ir]) {
                $buf[$y+$i-1][0] = $bs_obj->get_border_char(3, 0) . " ";
            }

            for my $ic (0..$N-1) {
                my $cell = $exptable->[$ir][$ic];

                # draw border between data cells
                for my $i (1 .. $exptable_row_heights->[$ir]) {
                    next unless defined $cell->[IDX_EXPTABLE_CELL_ORIG_ROWNUM];
                    $buf[$y+$i-1][$ic*2+2] = $ic == $N-1 ?
                        " " . $bs_obj->get_border_char(3, 2) :
                        " " . $bs_obj->get_border_char(3, 1) . " ";
                }

                # draw cell content
                if (defined $cell->[IDX_EXPTABLE_CELL_ORIG_ROWNUM]) {
                    my $lines = _get_exptable_cell_lines(
                        $exptable, $exptable_row_heights, $exptable_column_widths,
                        $len_between_cols, $ir, $ic);
                    for my $i (0..$#{$lines}) {
                        $buf[$y+$i][$ic*2+1] = $lines->[$i];
                    }
                }
            }
            $y += $exptable_row_heights->[$ir];
        }
    } # DRAW_EXPTABLE

    use DD; dd \@buf;
    join "", map {my $linebuf = $_; join("", grep {defined} @$linebuf) . "\n"} @buf;
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
