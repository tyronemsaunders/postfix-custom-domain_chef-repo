name 'postfix_mail'
maintainer 'Tyrone Saunders'
maintainer_email 'you@example.com'
license 'All Rights Reserved'
description 'Installs/Configures postfix_mail'
long_description 'Installs/Configures postfix_mail'
version '0.1.0'
chef_version '>= 12.1' if respond_to?(:chef_version)

# The `issues_url` points to the location where issues for this cookbook are
# tracked.  A `View Issues` link will be displayed on this cookbook's page when
# uploaded to a Supermarket.
#
# issues_url 'https://github.com/<insert_org_here>/postfix_mail/issues'

# The `source_url` points to the development reposiory for this cookbook.  A
# `View Source` link will be displayed on this cookbook's page when uploaded to
# a Supermarket.
#
# source_url 'https://github.com/<insert_org_here>/postfix_mail'

depends 'users',             '~> 5.2.1'
depends 'openssl',           '~> 7.1.0'
depends 'nginx',             '~> 7.0.0'
depends 'nodejs',            '~> 4.0.0'
depends 'cron',              '~> 4.2.0'
depends 'acme',              '~> 3.1.0'
depends 'postfix',           '~> 5.0.1'

depends 'postfix_base'
depends 'postfix_github'
depends 'postfix_nginx'
depends 'postfix_nodejs'
