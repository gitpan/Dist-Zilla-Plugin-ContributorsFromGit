#
# This file is part of Dist-Zilla-Plugin-ContributorsFromGit
#
# This software is Copyright (c) 2012 by Chris Weyl.
#
# This is free software, licensed under:
#
#   The GNU Lesser General Public License, Version 2.1, February 1999
#
package Dist::Zilla::Plugin::ContributorsFromGit;
{
  $Dist::Zilla::Plugin::ContributorsFromGit::VERSION = '0.006';
}

# ABSTRACT: Populate your 'CONTRIBUTORS' POD from the list of git authors

use utf8;

use Encode qw(decode_utf8);
use Moose;
use namespace::autoclean;
use MooseX::AttributeShortcuts 0.015;
use autobox::Core;
use File::Which 'which';
use List::AllUtils qw{ apply max uniq };
use Syntax::Keyword::Junction 'none';

use autodie 'system';
use IPC::System::Simple ( ); # explict dep for autodie system

use aliased 'Dist::Zilla::Stash::PodWeaver';

with
    'Dist::Zilla::Role::BeforeBuild',
    'Dist::Zilla::Role::RegisterStash',
    'Dist::Zilla::Role::MetaProvider',
    ;

# debugging...
#use Smart::Comments '###';

has contributor_list => (
    is      => 'lazy',
    isa     => 'ArrayRef[Str]',
    builder => sub {
        my $self = shift @_;
        my @authors = $self->zilla->authors->flatten;

        ### and get our list from git, filtering: "@authors"
        my @contributors = uniq sort
            grep  { $_ ne 'Your Name <you@example.com>' }
            grep  { none(@authors) eq $_                }
            apply { chomp; $_ = decode_utf8($_)         }
            `git log --format="%aN <%aE>"`
            ;

        return \@contributors;
    },
);

sub before_build {
    my $self = shift @_;

    # skip if we can't find git
    unless (which 'git') {
        $self->log('The "git" executable has not been found');
        return;
    }

    # XXX we should also check here that we're in a git repo, but I'm going to
    # leave that for the git stash (when it's not vaporware)

    ### get our stash, config...
    my $stash   = $self->zilla->stash_named('%PodWeaver');
    do { $stash = PodWeaver->new; $self->_register_stash('%PodWeaver', $stash) }
        unless defined $stash;
    my $config       = $stash->_config;
    my @contributors = $self->contributor_list->flatten;

    my $i = 0;
    do { $config->{"Contributors.contributors[$i]"} = $_; $i++ }
        for @contributors;

    # add contributor names as stopwords
    $i = 0;
    my @stopwords = uniq
        apply { split / /        }
        apply { /^(.*) <.*$/; $1 }
        @contributors
        ;
    do { $config->{"StopWords.include[$i]"} = $_; $i++ }
        for @stopwords;

    return;
}

sub metadata {
    my $self = shift @_;
    my $list = $self->contributor_list;
    return @$list ? { 'x_contributors' => $list } : {};
}

__PACKAGE__->meta->make_immutable;
!!42;

__END__

=pod

=encoding utf-8

=for :stopwords Chris Weyl David Golden <dagolden@cpan.org> Randy Stauner
<randy@magnificent-tears.com> Tatsuhiko Miyagawa <miyagawa@bulknews.net>
zilla BeforeBuild shortlog committer

=head1 NAME

Dist::Zilla::Plugin::ContributorsFromGit - Populate your 'CONTRIBUTORS' POD from the list of git authors

=head1 VERSION

This document describes version 0.006 of Dist::Zilla::Plugin::ContributorsFromGit - released April 03, 2013 as part of Dist-Zilla-Plugin-ContributorsFromGit.

=head1 SYNOPSIS

    ; in your dist.ini
    [ContributorsFromGit]

    ; in your weaver.ini
    [Contributors]

=head1 DESCRIPTION

This plugin makes it easy to acknowledge the contributions of others by
populating a L<%PodWeaver|Dist::Zilla::Stash::PodWeaver> stash with the unique
list of all git commit authors reachable from the current HEAD.

=head1 OVERVIEW

On collecting the unique list of reachable commit authors from git, we search
and remove any git authors from the list of authors L<Dist::Zilla> knows
about.  We then look for a stash named C<%PodWeaver>; if we don't find one
then we create an instance of L<Dist::Zilla::Stash::PodWeaver> and register it
with our zilla instance.  Then we add the list of contributors (the filtered
git authors list) to the stash in such a way that
L<Pod::Weaver::Section::Contributors> can find them.

Note that you do not need to have the C<%PodWeaver> stash created; it will be
added if it is not found.  However, your L<Pod::Weaver> config (aka
c<weaver.ini>) must include the
L<Contributors|Pod::Weaver::Section::Contributors> section plugin.

This plugin runs during the L<BeforeBuild|Dist::Zilla::Role::BeforeBuild>
phase.

The list of contributors is also added to distribution metadata under the custom
C<x_contributors> key.

=for Pod::Coverage before_build metadata

If you have duplicate contributors because of differences in committer name
or email you can use a C<.mailmap> file to canonicalize contributor names
and emails.  See L<git help shortlog|git-shortlog(1)> for details.

=head1 SEE ALSO

Please see those modules/websites for more information related to this module.

=over 4

=item *

L<Pod::Weaver::Section::Contributors>

=item *

L<Dist::Zilla::Stash::PodWeaver>

=back

=head1 SOURCE

The development version is on github at L<http://github.com/RsrchBoy/Dist-Zilla-Plugin-ContributorsFromGit>
and may be cloned from L<git://github.com/RsrchBoy/Dist-Zilla-Plugin-ContributorsFromGit.git>

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
https://github.com/RsrchBoy/Dist-Zilla-Plugin-ContributorsFromGit/issues

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

Chris Weyl <cweyl@alumni.drew.edu>

=head1 CONTRIBUTORS

=over 4

=item *

David Golden <dagolden@cpan.org>

=item *

Randy Stauner <randy@magnificent-tears.com>

=item *

Tatsuhiko Miyagawa <miyagawa@bulknews.net>

=back

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2012 by Chris Weyl.

This is free software, licensed under:

  The GNU Lesser General Public License, Version 2.1, February 1999

=cut
