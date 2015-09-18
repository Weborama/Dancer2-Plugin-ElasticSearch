package Dancer2::Plugin::ElasticSearch;

# ABSTRACT: Dancer2 plugin for obtaining Search::Elasticsearch handles

use strict;
use warnings;
use 5.012;
use Carp;
use autodie;
use utf8;

use Search::Elasticsearch;
use Try::Tiny;
use Dancer2::Plugin qw/:no_dsl/;

our $handles = {};

register 'elastic' => sub {
    my ($dsl, $name) = @_;
    $name //= 'default';

    # the classic fork/thread-safety mantra
    my $pid_tid = $$ . ($INC{'threads.pm'} ? '_' . threads->tid : '');

    my $elastic;
    if ($elastic = $handles->{$pid_tid}{$name}) {
        # got one from the cache.  done
    } else {
        # no handle in the cache, create one and stash it
        my $plugin_config = plugin_setting();
        unless (exists $plugin_config->{$name}) {
            die "No config for ElasticSearch client '$name'";
        }
        my $config = $plugin_config->{$name};
        my $params = $config->{params} // {};
        try {
            $elastic = Search::Elasticsearch->new(%{$params});
            # S::E does not actually connect until it needs to, but
            # we're already not creating the S::E object until we need
            # one!
            $elastic->ping;
        } catch {
            my $error = $_;
            die "Could not connect to ElasticSearch: $error";
        };
        $handles->{$pid_tid}{$name} = $elastic;
    }

    return $elastic;
};

register_plugin;

1;
