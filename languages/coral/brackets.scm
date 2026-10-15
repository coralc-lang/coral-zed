; Bracket matching for coral.
; Zed pairs string and char quotes from config.toml, so only the
; nesting delimiters are declared here.

("{") @open
("}") @close
("[") @open
("]") @close
("(") @open
(")") @close
