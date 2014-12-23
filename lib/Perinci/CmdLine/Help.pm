package Perinci::CmdLine::Help;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(gen_help);

our %SPEC;

$SPEC{gen_help} = {
    v => 1.1,
    summary => 'Generate help message for Perinci::CmdLine-based app',
    args => {
        program_name => {
            schema => 'str*',
            req => 1,
        },
        program_summary => {
            schema => 'str*',
        },
        meta => {
            schema => 'hash*',
            req => 1,
        },
    },
};
sub gen_help {
    my %args = @_;

    my $meta = $args{meta};
    my @help;

    # summary
    my $progname = $args{program_name};
    push @help, $progname;
    {
        my $sum = $args{program_summary} // $meta->{summary};
        last unless $sum;
        push @help, " - ", $sum, "\n";
    }

    my $clidocdata;

    # usage
    push @help, "\n";
    push @help, "Usage:\n";
    {
        # we have subcommands but user has not specified any to choose
        my $has_sc_no_sc = $self->subcommands && !length($r->{subcommand_name});

        push @help, "  $progname --help (or -h, -?)\n";
        push @help, "  $progname --version (or -v)\n";
        push @help, "  $progname --subcommands\n" if $has_sc_no_sc;

        require Perinci::Sub::To::CLIDocData;
        my $res;
        if ($has_sc_no_sc) {
            $res = Perinci::Sub::To::CLIDocData::gen_cli_doc_data_from_meta(
                meta => {v=>1.1}, meta_is_normalized => 1,
                common_opts  => $self->common_opts,
                per_arg_json => $self->per_arg_json,
                per_arg_yaml => $self->per_arg_yaml,
            );
        } else {
            $res = Perinci::Sub::To::CLIDocData::gen_cli_doc_data_from_meta(
                meta => $meta, meta_is_normalized => 1,
                common_opts  => $self->common_opts,
                per_arg_json => $self->per_arg_json,
                per_arg_yaml => $self->per_arg_yaml,
            );
        }
        die [500, "gen_cli_doc_data_from_meta failed: ".
                 "$res->[0] - $res->[1]"] unless $res->[0] == 200;
        $clidocdata = $res->[2];
        my $usage = $clidocdata->{usage_line};
        $usage =~ s/\[\[prog\]\]/$progname/;
        push @help, "  $usage\n";
    }

    # example
    {
        last unless @{ $clidocdata->{examples} };
        push @help, "\n";
        push @help, "Examples:\n";
        my $i = 0;
        my $egs = $clidocdata->{examples};
        for my $eg (@$egs) {
            $i++;
            my $cmdline = $eg->{cmdline};
            $cmdline =~ s/\[\[prog\]\]/$progname/;
            push @help, "  $eg->{summary}:\n" if $eg->{summary};
            push @help, "  % $cmdline\n";
            push @help, "\n" if $eg->{summary} && $i < @$egs;
        }
    }

    # description
    {
        my $desc = $args{program_description} // $meta->{description};
        last unless $desc;
        push @help, "\n";
        $desc =~ s/\A\n+//;
        $desc =~ s/\n+\z//;
        push @help, $desc, "\n";
    }

    # options
    {
        require Data::Dmp;

        my $opts = $clidocdata->{opts};
        last unless keys %$opts;

        # find all the categories
        my %cats; # val=[options...]
        for (keys %$opts) {
            push @{ $cats{$opts->{$_}{category}} }, $_;
        }

        for my $cat (sort keys %cats) {
            # find the longest option
            my @opts = sort {length($b)<=>length($a)} @{ $cats{$cat} };
            my $len = length($opts[0]);
            # sort again by name
            @opts = sort {
                (my $a_without_dash = $a) =~ s/^-+//;
                (my $b_without_dash = $b) =~ s/^-+//;
                lc($a) cmp lc($b);
            } @opts;
            push @help, "\n$cat:\n";
            for my $opt (@opts) {
                my $ospec = $opts->{$opt};
                my $arg_spec = $ospec->{arg_spec};
                my $is_bool = $arg_spec->{schema} &&
                    $arg_spec->{schema}[0] eq 'bool';
                my $show_default = exists($ospec->{default}) &&
                    !$is_bool && !$ospec->{is_base64} &&
                        !$ospec->{is_json} && !$ospec->{is_yaml} &&
                            !$ospec->{is_alias};

                my $add_sum = '';
                if ($ospec->{is_base64}) {
                    $add_sum = " (base64-encoded)";
                } elsif ($ospec->{is_json}) {
                    $add_sum = " (JSON-encoded)";
                } elsif ($ospec->{is_yaml}) {
                    $add_sum = " (YAML-encoded)";
                }

                my $argv = '';
                if (!$ospec->{main_opt} && defined($ospec->{pos})) {
                    if ($ospec->{greedy}) {
                        $argv = " (=arg[$ospec->{pos}-])";
                    } else {
                        $argv = " (=arg[$ospec->{pos}])";
                    }
                }

                my $cmdline_src = '';
                if (!$ospec->{main_opt} && defined($arg_spec->{cmdline_src})) {
                    $cmdline_src = " (or from $arg_spec->{cmdline_src})";
                    $cmdline_src =~ s!_or_!/!g;
                }

                push @help, sprintf(
                    "  %-${len}s  %s%s%s%s%s\n",
                    $opt,
                    $ospec->{summary}//'',
                    $add_sum,
                    $argv,
                    $cmdline_src,
                    ($show_default ?
                         " [".Data::Dmp::dmp($ospec->{default})."]":""),

                );
            }
        }
    }

    [200, "OK", join("", @help)];
}

1;
# ABSTRACT:

=for Pod::Coverage ^()$

=head1 DESCRIPTION

Currently used by L<Perinci::CmdLine::Lite> and L<App::riap>. Eventually I want
L<Perinci::CmdLine> to use this also (needs prettier and more sophisticated
formatting options first though).


=head1 SEE ALSO

=cut
