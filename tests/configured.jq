.[0] |
(.source.name == "configured-inventory") and
([.artifacts[].name] | sort == ["example", "example", "fixture-dep"]) and
(.descriptor.configuration.packages as $p |
  ($p.golang."search-remote-licenses" == false) and
  ($p.golang."search-local-mod-cache-licenses" == false) and
  ($p.golang."search-local-vendor-licenses" == false) and
  ($p.golang."use-packages-lib" == false) and
  ($p.javascript."search-remote-licenses" == false) and
  ($p.python."search-remote-licenses" == false) and
  ($p."java-archive"."use-network" == false) and
  ($p."java-archive"."use-maven-localrepository" == false) and
  ($p."java-archive"."resolve-transitive-dependencies" == false))
