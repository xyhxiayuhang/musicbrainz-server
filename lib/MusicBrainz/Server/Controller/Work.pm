package MusicBrainz::Server::Controller::Work;
use Moose;

BEGIN { extends 'MusicBrainz::Server::Controller'; }

use MusicBrainz::Server::Constants qw(
    $EDIT_WORK_CREATE
    $EDIT_WORK_EDIT
    $EDIT_WORK_MERGE
);

with 'MusicBrainz::Server::Controller::Role::Load' => {
    model       => 'Work',
    entity_name => 'work',
};
with 'MusicBrainz::Server::Controller::Role::Annotation';
with 'MusicBrainz::Server::Controller::Role::Alias';
with 'MusicBrainz::Server::Controller::Role::Details';
with 'MusicBrainz::Server::Controller::Role::Relationship';
with 'MusicBrainz::Server::Controller::Role::Rating';
with 'MusicBrainz::Server::Controller::Role::Tag';
with 'MusicBrainz::Server::Controller::Role::EditListing';

use aliased 'MusicBrainz::Server::Entity::ArtistCredit';

sub base : Chained('/') PathPart('work') CaptureArgs(0) { }

after 'load' => sub
{
    my ($self, $c) = @_;

    my $work = $c->stash->{work};
    $c->model('Work')->load_meta($work);
    if ($c->user_exists) {
        $c->model('Work')->rating->load_user_ratings($c->user->id, $work);
    }
};

sub show : PathPart('') Chained('load') 
{
    my ($self, $c) = @_;

    my $work = $c->stash->{work};
    $c->model('WorkType')->load($work);
    $c->model('ArtistCredit')->load($work);

    # need to call relationships for overview page
    $self->relationships($c);


    $c->stash->{template} = 'work/index.tt';
}

for my $action (qw( relationships aliases )) {
    after $action => sub {
        my ($self, $c) = @_;
        my $work = $c->stash->{work};
        $c->model('WorkType')->load($work);
        $c->model('ArtistCredit')->load($work);
    };
}



with 'MusicBrainz::Server::Controller::Role::Edit' => {
    form           => 'Work',
    edit_type      => $EDIT_WORK_EDIT,
};

with 'MusicBrainz::Server::Controller::Role::Merge' => {
    edit_type => $EDIT_WORK_MERGE,
    confirmation_template => 'work/merge_confirm.tt',
    search_template       => 'work/merge_search.tt',
};

before 'edit' => sub
{
    my ($self, $c) = @_;
    my $work = $c->stash->{work};
    $c->model('WorkType')->load($work);
    $c->model('ArtistCredit')->load($work);
};

after 'merge' => sub {
    my ($self, $c) = @_;
    $c->model('ArtistCredit')->load(
        $c->stash->{work}, $c->stash->{old}, $c->stash->{new}
    );
};

around '_merge_search' => sub {
    my $orig = shift;
    my ($self, $c, $query) = @_;

    my $results = $self->$orig($c, $query);
    $c->model('ArtistCredit')->load(map { $_->entity } @$results);
    return $results;
};

with 'MusicBrainz::Server::Controller::Role::Create' => {
    form      => 'Work',
    edit_type => $EDIT_WORK_CREATE,
    edit_arguments => sub {
        my ($self, $c) = @_;
        my $artist_gid = $c->req->query_params->{artist};
        if ( my $artist = $c->model('Artist')->get_by_gid($artist_gid) ) {
            my $rg = MusicBrainz::Server::Entity::Work->new(
                artist_credit => ArtistCredit->from_artist($artist)
            );
            $c->stash( initial_artist => $artist );
            return ( item => $rg );
        }
    }
};

1;

=head1 COPYRIGHT

Copyright (C) 2009 Lukas Lalinsky

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=cut
