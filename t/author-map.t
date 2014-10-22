use strict;
use warnings;
use utf8;

use autodie 'system';
use autobox::Core;

use Test::More;
use Test::TempDir 'scratch';
use Test::DZil;
use Directory::Scratch;
use File::chdir;
use File::Which 'which';
use IPC::System::Simple (); # explicit dep for autodie system
use Path::Class;

use lib 't/lib';

plan skip_all => 'git not found'
    unless which 'git';

$ENV{GIT_AUTHOR_EMAIL}    = 'Test Ing <test@test.ing>';
$ENV{GIT_COMMITTER_EMAIL} = 'Test Ing <test@test.ing>';

my $ds        = scratch;
my $dist_root = $ds->base;

my @AUTHORS = (
    'Chris Weyl <cweyl@alumni.drew.edu>',
    'Chris Weyl <cweyl@campusexplorer.com>',
    'Chris Weyl <chris.weyl@wps.io>',
);

{
    local $CWD = "$dist_root";
    system $_ for
        'git init',
        'touch foo && git add foo',
        "git commit --author '$AUTHORS[0]' -m 'one'",
        'touch bar && git add bar',
        "git commit --author '$AUTHORS[1]' -m 'two'",
        'touch baz && git add baz',
        "git commit --author '$AUTHORS[2]' -m 'three'",
        'touch aack && git add aack',
        q{git commit --author 'Your Name <you@example.com>' -m 'two'},
        ;
}

my $STASH_NAME = '%PodWeaver';
my @dist_ini   = qw(ContributorsFromGit FakeRelease);

my $tzil = Builder->from_config(
    { dist_root => "$dist_root" },
    {
        add_files => {
            'source/dist.ini' => simple_ini(@dist_ini),
        },
    },
);

isa_ok $tzil, 'Dist::Zilla::Dist::Builder';
ok $tzil->plugin_named('ContributorsFromGit'), 'tzil has our test plugin';

ok !$tzil->stash_named($STASH_NAME), 'tzil does not yet have the stash';
$tzil->release;

is_deeply
    [ sort @{$tzil->distmeta->{x_contributors}} ],
    [ 'Chris Weyl <rsrchboy@cpan.org>'          ],
    "x_contributors metadata"
    ;

my $stash = $tzil->stash_named($STASH_NAME);
isa_ok $stash, 'Dist::Zilla::Stash::PodWeaver';

my $cleanup_ok = is_deeply
    [
        sort
        map  { $stash->_config->{$_}                }
        grep { /^Contributors\.contributors\[\d+\]/ }
        $stash->_config->keys->flatten
    ],
    [ 'Chris Weyl <rsrchboy@cpan.org>' ],
    'contributors and git authors match up',
    ;

$ds->cleanup if $cleanup_ok;

done_testing;
