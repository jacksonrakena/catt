CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE card_type AS ENUM  (
    'prompt_d2p3',
    'prompt_p2',
    'prompt_normal',

    'response'
);

CREATE TABLE IF NOT EXISTS cards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type card_type NOT NULL,
    text varchar(200) NOT NULL,
    author UUID NOT NULL,
    created_at DATE DEFAULT now()
);

CREATE INDEX ix_card_type ON cards (type);

CREATE TABLE IF NOT EXISTS decks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name varchar(100) not null,
    author UUID NOT NULL,
    created_at DATE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cards_decks (
    card_id UUID REFERENCES cards (id) ON UPDATE CASCADE ON DELETE CASCADE,
    deck_id UUID REFERENCES decks (id) ON UPDATE CASCADE ON DELETE CASCADE,
    created_at DATE DEFAULT now()
);

CREATE INDEX ix_deck_type on cards_decks (deck_id);