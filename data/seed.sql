-- Flashcard Quiz data. The App tier's API creates these tables and inserts these
-- rows automatically on first connect; this file is the same data, for the backup
-- path (M11) and for reference. Safe to run more than once.
CREATE TABLE IF NOT EXISTS flashcards (
  id       INT          NOT NULL PRIMARY KEY,
  topic    VARCHAR(40)  NOT NULL,
  question VARCHAR(255) NOT NULL,
  answer   VARCHAR(255) NOT NULL
);

CREATE TABLE IF NOT EXISTS answers (
  id          INT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
  card_id     INT       NOT NULL,
  correct     BOOLEAN   NOT NULL,
  answered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT IGNORE INTO flashcards (id, topic, question, answer) VALUES
  (1,  'Basics',       'Which command shows what Terraform will change, without changing anything?', 'terraform plan'),
  (2,  'Basics',       'Which file does Terraform use to remember what it created?', 'The state file (terraform.tfstate)'),
  (3,  'State',        'Which S3 backend setting turns on native state locking?', 'use_lockfile = true'),
  (4,  'Language',     'Which meta-argument creates one resource per map key?', 'for_each'),
  (5,  'Language',     'Which block reads existing infrastructure without managing it?', 'A data block (data source)'),
  (6,  'Modules',      'How can a root module read a value from a child module?', 'Only through an output block'),
  (7,  'Networking',   'What lets servers in a private subnet reach the internet outbound?', 'A NAT Gateway'),
  (8,  'Security',     'Why does the DB security group need no egress rule for replies?', 'Security groups are stateful'),
  (9,  'Environments', 'Which expression holds the current workspace name?', 'terraform.workspace'),
  (10, 'Lifecycle',    'How do you prove nothing is left after terraform destroy?', 'terraform state list prints nothing');
