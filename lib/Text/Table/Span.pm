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
sub IDX_EXPTABLE_CELL_ORIG_ROWNUM()     {0}
sub IDX_EXPTABLE_CELL_ORIG_COLNUM()     {1}
sub IDX_EXPTABLE_CELL_ROWSPAN()         {2}
sub IDX_EXPTABLE_CELL_COLSPAN()         {3}
sub IDX_EXPTABLE_CELL_WIDTH()           {4} # visual width
sub IDX_EXPTABLE_CELL_HEIGHT()          {5} # visual height
sub IDX_EXPTABLE_CELL_TEXT()            {6}
sub IDX_EXPTABLE_CELL_PART_OF_ROWSPAN() {7} # bool
sub IDX_EXPTABLE_CELL_PART_OF_COLSPAN() {8} # bool

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
    my ($exptable, $row_heights, $column_widths,
        $bottom_borders, $len_between_cols, $y, $x) = @_;

    my $cell = $exptable->[$y][$x];
    my $text = $cell->[IDX_EXPTABLE_CELL_TEXT];
    my $height = 0;
    my $width  = 0;
    for my $ic (1..$cell->[IDX_EXPTABLE_CELL_COLSPAN]) {
        $width += $column_widths->[$x+$ic-1];
        $width += $len_between_cols if $ic > 1;
    }
    for my $ir (1..$cell->[IDX_EXPTABLE_CELL_ROWSPAN]) {
        $height += $row_heights->[$y+$ir-1];
        $height++ if $bottom_borders->[$y+$ir-2] && $ir > 1;
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
    my $cell_attrs = $args{cell_attrs} // [];

    my $bs_obj = Module::Load::Util::instantiate_class_with_optional_args({ns_prefix=>"BorderStyle"}, $bs_name);

    my $len_between_cols = length(" " . $bs_obj->get_border_char(3, 1) . " ");

    my $exptable = []; # [ [[$orig_rowidx,$orig_colidx,$rowspan,$colspan,...], ...], [[...], ...], ... ]
    my $exptable_bottom_borders = []; # idx=exptable rownum, val=bool
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
            push @{ $exptable->[$rownum] }, undef
                if (@{ $exptable->[$rownum] } == 0 ||
                defined($exptable->[$rownum][-1]));
            #use DDC; say "D:exptable->[$rownum] = ", DDC::dump($exptable->[$rownum]);
            my $exptable_colnum = firstidx {!defined} @{ $exptable->[$rownum] };
            #say "D:rownum=$rownum, exptable_colnum=$exptable_colnum";
            if ($exptable_colnum == -1) { $exptable_colnum = 0 }
            $exptable_bottom_borders->[$rownum] = $args{row_separator} ? 1:0;

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
                    $el = first {$_->[0] == $rownum && $_->[1] == $colnum && $_->[2]{rowspan}} @$cell_attrs;
                    $rowspan = $el->[2]{rowspan} if $el;
                    $el = first {$_->[0] == $rownum && $_->[1] == $colnum && $_->[2]{colspan}} @$cell_attrs;
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
                            #use DDC; say "D:length_heigt(".DDC::dump($text)."): ".DDC::dump($lh);
                            @widths  = _divide_int_to_n_ints($lh->[0], $colspan);
                            @heights = _divide_int_to_n_ints($lh->[1], $rowspan);
                        } else {
                            $exptable_cell->[IDX_EXPTABLE_CELL_PART_OF_COLSPAN] = 1 if $ic > 1;
                            $exptable_cell->[IDX_EXPTABLE_CELL_PART_OF_ROWSPAN] = 1 if $ir > 1;
                        }

                        $exptable_cell->[IDX_EXPTABLE_CELL_WIDTH]  = $widths[$ic-1];
                        $exptable_cell->[IDX_EXPTABLE_CELL_HEIGHT] = $heights[$ir-1];

                        #use DDC; dd $exptable; say ''; # debug
                    }
                    $M = $rownum+$ir if $M < $rownum+$ir;
                }

                $exptable_colnum += $colspan;
                $exptable_colnum++ while defined $exptable->[$rownum][$exptable_colnum];

                my $el;
                $exptable_bottom_borders->[$rownum+$rowspan-1] = 1 if
                    ($rownum == 0 && $args{header_row}) ||
                    (ref $cell eq 'HASH' && $cell->{bottom_border});
                $exptable_bottom_borders->[$rownum+$rowspan-2] = 1 if
                    $rownum > 0 &&
                    (ref $cell eq 'HASH' && $cell->{top_border});
                } # for a row
            $N = $exptable_colnum if $N < $exptable_colnum;
        } # for rows

        for my $ir (0..$M-1) {
            my $el;
            $el = first {$_->[0] == $ir && $_->[1] == 0 && $_->[2]{bottom_border}} @$cell_attrs;
            $el->{bottom_border} and $exptable_bottom_borders->[$ir] = 1;
            $el = first {$_->[0] == $ir && $_->[1] == 0 && $_->[2]{top_border}} @$cell_attrs;
            $el->{top_border} && $ir > 0 and $exptable_bottom_borders->[$ir-1] = 1;
        }

    } # CONSTRUCT_EXPTABLE
    #use DDC; dd $exptable; # debug
    #print "D: exptable size: $M x $N (HxW)\n"; # debug

  OPTIMIZE_EXPTABLE: {
        # TODO

        # 2. we reduce extraneous columns and rows if there are colspan that are
        # too many. for example, if all exptable cells in column 1 has colspan=2
        # (or one row has colspan=2 and another row has colspan=3), we might as
        # remove 1 column because the extra column span doesn't have any
        # content. same case for extraneous row spans.

        # 2a. remove extra undefs. skip this. doesn't make a difference.
        #for my $exptable_row (@{ $exptable }) {
        #    splice @$exptable_row, $N if @$exptable_row > $N;
        #}

        1;
    } # OPTIMIZE_EXPTABLE
    use DDC; dd $exptable; # debug

    my $exptable_column_widths  = []; # idx=exptable colnum
    my $exptable_row_heights    = []; # idx=exptable rownum
  DETERMINE_SIZE_OF_EACH_EXPTABLE_COLUMN_AND_ROW: {
        # 3. before we draw the exptable, we need to determine the width and
        # height of each exptable column and row.
        use DDC;
        for my $ir (0..$M-1) {
            my $exptable_row = $exptable->[$ir];
            $exptable_row_heights->[$ir] = max(
                1, map {$_->[IDX_EXPTABLE_CELL_HEIGHT] // 0} @$exptable_row);
        }

        for my $ic (0..$N-1) {
            $exptable_column_widths->[$ic] = max(
                1, map {$exptable->[$_][$ic] ? $exptable->[$_][$ic][IDX_EXPTABLE_CELL_WIDTH] : 0} 0..$M-1);
        }
    } # DETERMINE_SIZE_OF_EACH_EXPTABLE_COLUMN_AND_ROW
    use DDC; print "column widths: "; dd $exptable_column_widths; # debug
    use DDC; print "row heights: "; dd $exptable_row_heights; # debug
    use DDC; print "bottom borders: "; dd $exptable_bottom_borders; # debug

    # each elem is an arrayref containing characters to render a line of the
    # table, e.g. for element [0] the row is all borders. for element [1]:
    # [$left_border_str, $exptable_cell_content1, $border_between_col,
    # $exptable_cell_content2, ...]. all will be joined together with "\n" to
    # form the final rendered table.
    my @buf;

  DRAW_EXPTABLE: {
        # 4. finally we draw the (exp)table.

        my $y = 0;

        for my $ir (0..$M-1) {

          DRAW_TOP_BORDER:
            {
                last unless $ir == 0;
                my $b_y = $args{header_row} ? 0 : 6;
                my $b_topleft    = $bs_obj->get_border_char($b_y, 0);
                my $b_topline    = $bs_obj->get_border_char($b_y, 1);
                my $b_topbetwcol = $bs_obj->get_border_char($b_y, 2);
                my $b_topright   = $bs_obj->get_border_char($b_y, 3);
                last unless length $b_topleft || length $b_topline || length $b_topbetwcol || length $b_topright;
                $buf[$y][0] = $b_topleft;
                for my $ic (0..$N-1) {
                    my $cell_right = $ic < $N-1 ? $exptable->[$ir][$ic+1] : undef;
                    my $cell_right_has_content = defined $cell_right && defined $cell_right->[IDX_EXPTABLE_CELL_ORIG_ROWNUM];
                    $buf[$y][$ic*4+2] = $bs_obj->get_border_char($b_y, 1, $exptable_column_widths->[$ic]+2); # +1, +2, +3
                    $buf[$y][$ic*4+4] = $ic == $N-1 ? $b_topright : ($cell_right_has_content ? $b_topbetwcol : $b_topline);
                }
                $y++;
            } # DRAW_TOP_BORDER

            # DRAW_DATA_OR_HEADER_ROW
            {
                # draw left border
                my $b_y = $ir == 0 && $args{header_row} ? 1 : 3;
                for my $i (1 .. $exptable_row_heights->[$ir]) {
                    $buf[$y+$i-1][0] = $bs_obj->get_border_char($b_y, 0);
                }

                my $lines;
                for my $ic (0..$N-1) {
                    my $cell = $exptable->[$ir][$ic];

                    # draw border between data cells
                    for my $i (1 .. $exptable_row_heights->[$ir]) {
                        next if $ic == $N-1;
                        next if $cell->[IDX_EXPTABLE_CELL_PART_OF_COLSPAN];
                        $buf[$y+$i-1][$ic*4+1] = " ";
                        $buf[$y+$i-1][$ic*4+2] = $bs_obj->get_border_char($b_y, 1);
                        $buf[$y+$i-1][$ic*4+3] = " ";
                    }

                    # draw cell content
                    if (defined $cell->[IDX_EXPTABLE_CELL_ORIG_ROWNUM]) {
                        $lines = _get_exptable_cell_lines(
                            $exptable, $exptable_row_heights, $exptable_column_widths,
                            $exptable_bottom_borders, $len_between_cols, $ir, $ic);
                        for my $i (0..$#{$lines}) {
                            $buf[$y+$i][$ic*4+1] = " ";
                            $buf[$y+$i][$ic*4+2] = $lines->[$i];
                            $buf[$y+$i][$ic*4+3] = " ";
                        }
                        #use DDC; say "D: Drawing exptable_cell($ir,$ic): ", DDC::dump($lines);
                    }

                    # draw right border
                    if ($ic == $N-1) {
                        if (!$cell->[IDX_EXPTABLE_CELL_PART_OF_COLSPAN]) {
                            my $b_y = $ir == 0 && $args{header_row} ? 1 : 3;
                            for my $i (1 .. $exptable_row_heights->[$ir]) {
                                $buf[$y+$i-1][$ic*4+3] = " ";
                                $buf[$y+$i-1][$ic*4+4] = $bs_obj->get_border_char($b_y, 2);
                            }
                        }
                    }

                }
            } # DRAW_DATA_OR_HEADER_ROW

            $y += $exptable_row_heights->[$ir];

          DRAW_ROW_SEPARATOR:
            {
                last unless $ir < $M-1;
                last unless $exptable_bottom_borders->[$ir];
                my $b_y = $ir == 0 && $args{header_row} ? 2 : 4;
                my $b_betwrowleft    = $bs_obj->get_border_char($b_y, 0);
                my $b_betwrowline    = $bs_obj->get_border_char($b_y, 1);
                my $b_betwrowbetwcol = $bs_obj->get_border_char($b_y, 2);
                my $b_betwrowright   = $bs_obj->get_border_char($b_y, 3);
                last unless length $b_betwrowleft || length $b_betwrowline || length $b_betwrowbetwcol || length $b_betwrowright;
                my $b_betwrowbetwcol_notop = $bs_obj->get_border_char($b_y, 4);
                my $b_betwrowbetwcol_nobot = $bs_obj->get_border_char($b_y, 5);
                my $b_betwrowbetwcol_noleft  = $bs_obj->get_border_char($b_y, 6);
                my $b_betwrowbetwcol_noright = $bs_obj->get_border_char($b_y, 7);
                my $b_yd = $ir == 0 && $args{header_row} ? 2 : 3;
                my $b_datarowleft    = $bs_obj->get_border_char($b_yd, 0);
                my $b_datarowbetwcol = $bs_obj->get_border_char($b_yd, 1);
                my $b_datarowright   = $bs_obj->get_border_char($b_yd, 2);
                for my $ic (0..$N-1) {
                    my $cell_topleft  = $exptable->[$ir][$ic];
                    my $cell_topright = $ic < $N-1 ? $exptable->[$ir][$ic+1] : undef;
                    my $cell_botleft  = $ir < $M-1 ? $exptable->[$ir+1][$ic] : undef;
                    my $cell_botright = $ir < $M-1 && $ic < $N-1 ? $exptable->[$ir+1][$ic+1] : undef;
                    my $cell_topleft_part_of_rowspan  = defined $cell_topleft->[IDX_EXPTABLE_CELL_PART_OF_ROWSPAN];
                    my $cell_topleft_part_of_colspan  = defined $cell_topleft->[IDX_EXPTABLE_CELL_PART_OF_COLSPAN];
                    my $cell_topright_part_of_rowspan = defined $cell_topright && defined $cell_topright->[IDX_EXPTABLE_CELL_PART_OF_ROWSPAN];
                    my $cell_topright_part_of_colspan = defined $cell_topright && defined $cell_topright->[IDX_EXPTABLE_CELL_PART_OF_COLSPAN];
                    my $cell_botleft_part_of_rowspan  = defined $cell_botleft  && defined $cell_botleft ->[IDX_EXPTABLE_CELL_PART_OF_ROWSPAN];
                    my $cell_botleft_part_of_colspan  = defined $cell_botleft  && defined $cell_botleft ->[IDX_EXPTABLE_CELL_PART_OF_COLSPAN];
                    my $cell_botright_part_of_rowspan = defined $cell_botright && defined $cell_botright->[IDX_EXPTABLE_CELL_PART_OF_ROWSPAN];
                    my $cell_botright_part_of_colspan = defined $cell_botright && defined $cell_botright->[IDX_EXPTABLE_CELL_PART_OF_COLSPAN];

                    # left border
                    if ($ic == 0) {
                        $buf[$y][$ic*4] = $cell_botleft_part_of_rowspan ? $b_datarowleft : $b_betwrowleft;
                    }

                    # along the width of cell content
                    if ($cell_botleft_part_of_rowspan) {
                        # space before cell content
                        $buf[$y][$ic*4+1] = " ";

                        # space after cell content
                        $buf[$y][$ic*4+3] = " ";
                    } else {
                        $buf[$y][$ic*4+2] = $bs_obj->get_border_char($b_y, 1, $exptable_column_widths->[$ic]+2);
                    }

                    my $char;
                    if ($ic == $N-1) {
                        # rightmost
                        if ($cell_botleft_part_of_rowspan) {
                            $char = $b_datarowright;
                        } else {
                            $char = $b_betwrowright;
                        }
                    } else {
                        # between cells
                        if ($cell_topright_part_of_colspan) {
                            if ($cell_botright_part_of_colspan) {
                                if ($cell_botleft_part_of_rowspan) {
                                    $char = "";
                                } else {
                                    $char = $b_betwrowline;
                                }
                            } else {
                                $char = $b_betwrowbetwcol_notop;
                            }
                        } else {
                            if ($cell_botright_part_of_colspan) {
                                $char = $b_betwrowbetwcol_nobot;
                            } else {
                                if ($cell_botleft_part_of_rowspan) {
                                    if ($cell_botright_part_of_rowspan) {
                                        $char = $b_datarowbetwcol;
                                    } else {
                                        $char = $b_betwrowbetwcol_noleft;
                                    }
                                } elsif ($cell_botright_part_of_rowspan) {
                                    $char = $b_betwrowbetwcol_noright;
                                } else {
                                    $char = $b_betwrowbetwcol;
                                }
                            }
                        }
                    }
                    $buf[$y][$ic*4+4] = $char;

                }
                $y++;
            } # DRAW_ROW_SEPARATOR

          DRAW_BOTTOM_BORDER:
            {
                last unless $ir == $M-1;
                my $b_y = $ir == 0 && $args{header_row} ? 7 : 5;
                my $b_botleft    = $bs_obj->get_border_char($b_y, 0);
                my $b_botline    = $bs_obj->get_border_char($b_y, 1);
                my $b_botbetwcol = $bs_obj->get_border_char($b_y, 2);
                my $b_botright   = $bs_obj->get_border_char($b_y, 3);
                last unless length $b_botleft || length $b_botline || length $b_botbetwcol || length $b_botright;
                $buf[$y][0] = $b_botleft;
                for my $ic (0..$N-1) {
                    my $cell_right = $ic < $N-1 ? $exptable->[$ir][$ic+1] : undef;
                    my $cell_right_part_of_colspan = defined $cell_right && $cell_right->[IDX_EXPTABLE_CELL_PART_OF_COLSPAN];
                    $buf[$y][$ic*4+2] = $bs_obj->get_border_char($b_y, 1, $exptable_column_widths->[$ic]+2);
                    $buf[$y][$ic*4+4] = $ic == $N-1 ? $b_botright : ($cell_right_part_of_colspan ? $b_botline : $b_botbetwcol);
                }
                $y++;
            } # DRAW_BOTTOM_BORDER

        }
    } # DRAW_EXPTABLE

    for my $row (@buf) { for (@$row) { $_ = "" if !defined($_) } } # debug. remove undef to "" to save dump width
    use DDC; dd \@buf;
    join "", (map { my $linebuf = $_; join("", grep {defined} @$linebuf)."\n" } @buf);
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

Or, you can also use the C<cell_attrs> option:

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
     cell_attrs => [
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
spans, and border style>.


=head1 FUNCTIONS

=head2 generate_table

Usage:

 my $table_str = generate_table(%args);

Arguments:

=item * rows

Array of arrayrefs (of strings or hashrefs). Required. Each array element is a
row of cells. A cell can be a string like C<"foo"> specifying only the text
(equivalent to C<<{ text=>"foo" >>) or a hashref which allows you to specify a
cell's text (C<text>) as well as attributes like C<rowspan> (int, >= 1),
C<colspan> (int, >= 1), C<bottom_border> (bool), or C<top_border>.

Currently, C<top_border> and C<bottom_border> needs to be specified for the
first column of a row and will take effect for the whole row.

Alternatively, you can also specify cell attributes using L</cell_attrs>
argument.

=item * header_row

Boolean. Optional. Default 0. Whether to treat the first row as the header row,
which means draw a separator line between it and the rest.

=item * border_style

Str. Optional. Default to C<ASCII::SingleLineDoubleAfterHeader>. This is Perl
module under the L<BorderStyle> namespace, without the namespace prefix. To see
how a border style looks like, you can use the CLI L<show-border-style> from
L<App::BorderStyleUtils>.

=item * cell_attrs

Array of records. Optional. Each record is a 3-element arrayref: C<< [$row_idx,
$col_idx, \%styles] >>. C<$row_idx> and C<$col_idx> are zero-based. See L</rows>
for the list of known attributes.

Alternatively, you can specify a cell's attribute in the L</rows> argument
directly, by specifying a cell as hashref.

=item * row_separator

Boolean. Optional. Default 0. If set to true, will add a separator between data
rows. Equivalent to setting C<bottom_border> or C<top_border> attribute for each
row.

=back


=head1 SEE ALSO

L<Text::Table::TinyBorderStyle>

HTML &lt;TABLE&gt; element,
L<https://www.w3.org/TR/2014/REC-html5-20141028/tabular-data.html>,
L<https://www.w3.org/html/wiki/Elements/table>

=cut
