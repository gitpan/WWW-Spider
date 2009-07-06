package WWW::Spider;

=head1 NAME

WWW::Spider - flexible Internet spider for fetching and analyzing websites

=head1 VERSION

This document describes C<WWW::Spider> version 0.01_10

=head1 SYNOPSIS

 #configuration
 my $spider=new WWW::Spider;
 $spider=new WWW::Spider({UASTRING=>"mybot"});
 
 print $spider->uastring;
 $spider->uastring('New UserAgent String');
 $spider->user_agent(new LWP::UserAgent);
 
 #basic stuff
 print $spider->get_page_response('http://search.cpan.org/') -> content;
 print $spider->get_page_content('http://search.cpan.org/');
 $spider->get_links_from('http://google.com/'); #get array of URLs
 
 #registering hooks
 
 #crawling

=head1 DESCRIPTION

WWW::Spider is a customizable Internet spider intended to be used for
fetching and analyzing websites.  Features include:

=over

=item * basic methods for high-level html handling

=item * the manner in which pages are retrieved is customizable

=item * callbacks for when pages are fetched, errors caused, etc...

=item * caching

=item * thread-safe operation, and optional multithreading operation
(faster)

=item * a high-level implementation of a 'graph' of either pages or
sites (as defined by the callback) which can be analyzed

=back

=cut

use strict;
use warnings;

use threads;
use Carp;
use LWP::UserAgent;
use HTTP::Request;
use Thread::Queue;

use WWW::Spider::Graph;
use WWW::Spider::Hooklist;

use vars qw( $VERSION );
$VERSION = '0.01_10';

=pod

=head1 FUNCTIONS

=head2 PARAMETERS

Parameter getting and setting functions.

=over

=item new WWW::Spider([%params])

Constructor for C<WWW::Spider>

=cut

sub new {
    my $class=shift;
    my $self={};
    my $params=shift || {};

=pod

Arguments include:

=over

=item * UASTRING

The useragent string to be used.  The default is "WWW::Spider"

=cut

    my $uastring=$params->{UASTRING} || 'WWW::Spider';

=pod

=item * USER_AGENT

The LWP::UserAgent to use.  If this is specified, the UASTRING
argument is ignored.

=cut

    my $ua=new LWP::UserAgent;
    $ua->agent($uastring);
    $ua=$params->{USER_AGENT} || $ua;
    $self->{USER_AGENT}=$ua;

    $self->{HOOKS}=new WWW::Spider::Hooklist(['']);

    bless $self,$class;
    return $self;
}

=pod

=back

=item ->user_agent [LWP::UserAgent]

Returns/sets the user agent being used by this object.

=cut

sub user_agent {
    my $self=shift;
    my $original=$self->{USER_AGENT};
    $self->{USER_AGENT}=$_[0] if exists $_[0];
    return $original
}

=pod

=item ->uastring [STRING]

Returns/sets the user agent string being used by this object.

=cut

sub uastring {
    my $self=shift;
    return $self->{USER_AGENT}->agent($_[0]);
}

=pod

=back

=head2 GENERAL

These functions could be implemented anywhere - nothing about what
they do is special do WWW::Spider.  Mainly, they are just conveiniance
functions for the rest of the code.

=over

=item ->get_page_content URL

Returns the contents of the page at URL.

=cut

sub get_page_content {
    my ($self,$url)=@_;
    return $self->get_page_response($url)->content;
}

=pod

=item ->get_page_response URL

Returns the HTTP::Response object corresponding to URL

=cut

sub get_page_response {
    my ($self,$url)=@_;
    return $self->{USER_AGENT}->get($url);
}

=pod

=back

=head2 SPIDER

These functions implement the spider functionality. 

=over

=item ->crawl URL MAX_DEPTH

Crawls URL to the specified maxiumum depth.  This is implemented as a
breadth-first search.

The default value for MAX_DEPTH is 0.

=cut

sub crawl {
    (my $self,my $url,my $max_depth)=@_;
    $max_depth=$max_depth || 0;
    croak "fatal: crawl called with empty url string" unless $url;
    my $response=$self->get_page_response($url);
    $self->handle_response($response);
    $self->crawl_content($response->content,$max_depth,$url);
}

=pod

=item ->handle_url URL

The same as C<crawl(URL,0)>.

=cut

sub handle_url {
    my ($self,$url)=@_;
    croak "fatal: handle_url called with empty url string" unless $url;
    $self->handle_response($self->get_page_response($url));
}

=pod

=item ->crawl_content STRING [$MAX_DEPTH] [$SOURCE]

Treats STRING as if it was encountered during a crawl, with a
remaining maximum depth of MAX_DEPTH.  The crawl is implemented as a
breadth-first search using C<Thread::Queue>.

The default value for MAX_DEPTH is 0.

The assumption is made that handlers have already been called on this
page (otherwise, implementation would be impossible).

=cut

sub crawl_content {
    (my $self,my $content,my $max_depth,my $source)=@_;
    croak "fatal: crawl_content called with empty content string" unless $content;
    $max_depth=$max_depth || 0;
    my %urls_done;
    $urls_done{$source}=1;
    my @links=$self->get_links_from_content($content,$source);
    my $q=new Thread::Queue(@links);
    my $depth=0;
    $q->enqueue('--');
    while($q->pending()>0 and $max_depth>$depth) {
	my $link=$q->dequeue;
	if($link eq '--') {
	    $depth++;
	    $q->enqueue('--');
	    next;
	}
	next if $urls_done{$link};
	my $response=$self->get_page_response($link);
	next unless $response->header('Content-type')=~/^text/;
	my $tmp_content=$response->content;
	$self->handle_response($response);
	$urls_done{$link}=1;
	@links=$self->get_links_from_content($tmp_content,$link);
	for my $a (@links) {
	    next if $urls_done{$a};
	    $q->enqueue($a);
	}
    }
}

=pod

=item ->handle_response HTTP::RESPONSE

Handles the HTTP reponse, calling the appropriate hooks, without
crawling any other pages.

=cut

sub handle_response {
    my ($self, $content)=@_;
    carp "warning: handle_response called with empty content string" unless $content;
}

=pod

=item ->get_links_from URL

Returns a list of URLs linked to from URL.

=cut

sub get_links_from {
    my ($self,$url)=@_;
    croak "fatal: get_links_from called with empty url string" unless $url;
    return $self->get_links_from_content($self->get_page_content($url),$url);    
}

=pod

=item ->get_links_from_content $CONTENT [$SOURCE]

Returns a list of URLs linked to in STRING.  When a URL is discovered
that is not complete, it is fixed by assuming that is was found on
SOURCE.  If there is no source page specified, bad URLs are treated as
if they were linked to from http://localhost/.

SOURCE must be a valid and complete url.

=cut

sub get_links_from_content {
    (my $self,my $content,my $source)=@_;
    croak "fatal: get_links_from_content called with empty content string" unless $content;
    my @list;
    my $domain="http://localhost/";
    my $root="http://localhost/";
    if($source) {
	$source=~/^(https?:\/\/[^\/]+\/)(.*)$/g;
	$domain=$1;
	$root=$1.$2;
	if($root=~/^(.+\/)[^\/]+$/g) {
	    $root=$1;
	}
    }
    while($content=~/<a ([^>]* )?href *= *\"([^\"]*)\"/msg) {
	my $partial=$2;
	my $url;
	if($partial=~/^http:\/\/.*\//) {
	    $url=$partial;
	} elsif($partial=~/^http:\/\//) {
	    $url=$partial."/";
	} elsif($partial=~/^\/(.*)$/g) {
	    $url=$domain.$1;
	} else {
	    $url=$root.$partial;
	}
	push @list,$url;
    }
    return @list;
}

=pod

=back

=head2 CALLBACKS AND HOOKS

All hook registration and deletion functions are considered atomic.
If five hooks have been registered, and then all of them are deleted
in one operation, there will be no page for which fewer than five but
more than zero of those hooks are called (unless some hooks are added
afterwords).

The legal hook strings are:

=over

=item * handle-page

Called whenever a crawlable page is reached.

Arguments: CONTENT, URL

Return: 

=item * handle-response

Called on an HTTP response, successfull, crawlable, or otherwise.

Arguments:

Return:

=item * handle-failure

Called on any failed HTTP response.

Arguments:

Return:

=back

Functions for handling callbacks are:

=over

=item ->call_hooks HOOK-STRING, @ARGS

Calls all of the registered HOOK-STRING callbacks with @ARGS.  This
function returns a list of all of the return values (in some
unspecified order) which are to be handled appropriately by the
caller.

=cut

sub call_hooks {
    my ($self,$name,@args)=@_;
    my @list=$self->get_hooks($name);
    my @ret;
    for my $hook (@list) {
	push @ret,&$hook(@args);
    }
    return @ret;
}

=pod

=item ->register_hook HOOK-STRING, SUB, [{OPTIONS}]

Registers a subroutine to be run on HOOK-STRING.  Has no return value.
Valid options are:

=over

=item * FORK

Set to a non-zero value if you want this hook to be run in a separate
thread.  This means that, among other things, the return value will
not have the same affect (or even a well defined affect).

=back

=cut

sub register_hook {
    my ($self,$name,$hook,$options)=@_;
}

=pod

=item ->get_hooks [HOOK-STRING]

Returns all hooks corresponding to HOOK-STRING.  If HOOK-STRING is not
given, returns all hooks.

=cut

sub get_hooks {
    my ($self,$name)=@_;
}

=pod

=item ->clear_hooks [HOOK-STRING]

Removes all hooks corresponding to HOOK-STRING.  If HOOK-STRING is not
given, it deletes all hooks.

=cut

sub clear_hooks {
    my ($self,$name)=@_;
}

1;

__END__

=back

=head1 BUGS AND LIMITATIONS

=over

=item * Hooks are not yet fully implemented.

=item * Hook list modifications are not atomic

=back

=head1 MODULE DEPENDENCIES

WWW::Spider depends on several other modules that allow it to get and
parse HTML code.  Currently used are:

=over

=item * C<Carp>

=item * C<LWP::UserAgent>

=item * C<HTTP::Request>

=item * C<Thread::Queue>

=item * C<Thread::Resource::RWLock>

=back

Other modules will likely be added to this list in the future.  Candidates are:

=over

=item * HTML::*

=back

=head1 SEE ALSO

=over

=item * C<WWW::Robot>

Another web crawler, with rather different capabilities.

=item * C<WWW::Spider::Graph>

Implementation of a graph based on WWW::Spider.

=item * C<WWW::Spider::Hooklist>

A thread-safe list of hooks.

=back

=head1 AUTHOR

C<WWW::Spider> is written and maintained by Scott Lawrence (bytbox@gmail.com)

=head1 COPYRIGHT AND LICENSE

Copyright 2009 Scott Lawrence, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
