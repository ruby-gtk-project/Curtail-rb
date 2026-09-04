{
  description = "curtail-rb — a Ruby GTK4 port of Curtail";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        ruby = pkgs.ruby_3_3;

        # Curtail shells out to these; without them every compression fails.
        compressionTools = with pkgs; [ jpegoptim oxipng pngquant libwebp scour ];

        # Shared libraries every ruby-gnome extension links against.
        gtkStack = with pkgs; [
          glib
          gobject-introspection
          cairo
          pango
          gdk-pixbuf
          graphene
          atk
          gtk4
          libadwaita
          harfbuzz
          # Result rows preview SVGs through gdk-pixbuf, which needs librsvg's
          # loader or the thumbnail silently comes back nil.
          librsvg
          webp-pixbuf-loader
        ]
        # The Ruby `pkg-config` gem resolves `Requires.private` transitively and
        # hard-fails if any .pc in the chain is missing, so gtk4's whole
        # private closure has to be on PKG_CONFIG_PATH, not just its public deps.
        ++ (with pkgs; [
          fontconfig
          freetype
          libepoxy
          libpng
          libxkbcommon
          pcre2
          util-linux
          wayland
          zlib
          fribidi
          libdatrie
          libthai
          libselinux
          libsepol
          expat
          brotli
          bzip2
          graphite2
          icu
          libffi
          libxml2
          lerc
          libdeflate
          xz
          zstd
        ])
        ++ (with pkgs; [
          libx11
          libxau
          libxcursor
          libxdmcp
          libxext
          libxfixes
          libxi
          libxinerama
          libxrandr
          libxrender
          libxcb
          xorgproto
        ]);

        # gdk-pixbuf has PNG and JPEG built in, but SVG and WebP arrive as
        # loadable modules — and the result rows preview all four formats, so
        # both modules have to be in one loaders.cache.
        pixbufLoaders = pkgs.runCommand "curtail-rb-pixbuf-loaders" { } ''
          mkdir -p $out
          ${pkgs.gdk-pixbuf.dev}/bin/gdk-pixbuf-query-loaders \
            ${pkgs.librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders/*.so \
            ${pkgs.webp-pixbuf-loader}/lib/gdk-pixbuf-2.0/2.10.0/loaders/*.so \
            > $out/loaders.cache
        '';

        # ruby-gnome gems build C extensions with extconf.rb + the pkg-config
        # gem; nixpkgs only ships gemConfig entries for the GTK3-era subset, so
        # the GTK4 gems get their build inputs declared here.
        rubyGnomeGem = attrs: {
          nativeBuildInputs = [ pkgs.pkg-config ];
          buildInputs = gtkStack;
        };

        gemConfig = pkgs.defaultGemConfig // {
          gdk4 = rubyGnomeGem;
          gsk4 = rubyGnomeGem;
          gtk4 = rubyGnomeGem;
          graphene1 = rubyGnomeGem;
          adwaita = rubyGnomeGem;
        };

        # `makeSearchPath` would take each package's *first* output, and glib's
        # first output is `bin`, which carries no typelibs — hence the explicit
        # `.out`. at-spi2-core is here for the Atk typelib.
        typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0"
          (map (drv: drv.out or drv) (gtkStack ++ [ pkgs.at-spi2-core ]));

        gems = pkgs.bundlerEnv {
          name = "curtail-rb-gems";
          inherit ruby gemConfig;
          gemdir = ./.;
        };

      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "curtail-rb";
          version = "0.1.0";
          src = ./.;

          # glib is here for its setup hook, which relocates the gschema into
          # share/gsettings-schemas/<name> and compiles it there.
          nativeBuildInputs = [ pkgs.makeWrapper pkgs.glib ];
          buildInputs = [ gems ] ++ gtkStack;

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/curtail-rb $out/share/applications
            cp -r lib data $out/share/curtail-rb/
            # bin/ has to sit next to lib/ for the launcher's require_relative.
            install -Dm755 bin/curtail-rb $out/share/curtail-rb/bin/curtail-rb

            cp data/com.github.huluti.Curtail.Rb.desktop $out/share/applications/
            install -Dm644 data/icons/hicolor/scalable/apps/com.github.huluti.Curtail.Rb.svg \
              -t $out/share/icons/hicolor/scalable/apps

            # Gio::Settings.new aborts the process if it cannot find the
            # schema, so it has to be compiled and reachable. Installing it
            # here lets glib's setup hook relocate and compile it into
            # share/gsettings-schemas/<name>, which the wrapper points at.
            install -Dm644 data/com.github.huluti.Curtail.Rb.gschema.xml \
              -t $out/share/glib-2.0/schemas

            # -rbundler/setup puts the bundled gems on the load path, and
            # GI_TYPELIB_PATH keeps GObject-Introspection from re-registering
            # types the cairo gem's C extension has already registered.
            makeWrapper ${gems.wrappedRuby}/bin/ruby $out/bin/curtail-rb \
              --add-flags "-rbundler/setup" \
              --add-flags "$out/share/curtail-rb/bin/curtail-rb" \
              --set GI_TYPELIB_PATH "${typelibPath}" \
              --set GDK_PIXBUF_MODULE_FILE "${pixbufLoaders}/loaders.cache" \
              --prefix PATH : "${pkgs.lib.makeBinPath compressionTools}" \
              --prefix XDG_DATA_DIRS : "$out/share" \
              --prefix XDG_DATA_DIRS : "$out/share/gsettings-schemas/$pname-$version" \
              --prefix XDG_DATA_DIRS : "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}" \
              --prefix XDG_DATA_DIRS : "${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}" \
              --prefix XDG_DATA_DIRS : "${pkgs.adwaita-icon-theme}/share"

            runHook postInstall
          '';

          # glib's setup hook relocates the schema into
          # share/gsettings-schemas/<name> but does not compile it there, and
          # Gio::Settings.new aborts the process when the schema is missing —
          # so the compile is done explicitly, after the relocation.
          postFixup = ''
            ${pkgs.glib.dev}/bin/glib-compile-schemas \
              $out/share/gsettings-schemas/$pname-$version/glib-2.0/schemas
          '';
        };

        apps.default = flake-utils.lib.mkApp { drv = self.packages.${system}.default; };

        devShells.default = pkgs.mkShell {
          name = "curtail-rb-devshell";

          packages = [
            gems
            gems.wrappedRuby
            pkgs.bundler
            pkgs.bundix
            pkgs.pkg-config
            pkgs.glib.dev
            pkgs.adwaita-icon-theme
            pkgs.gsettings-desktop-schemas
          ] ++ gtkStack ++ compressionTools;

          # Icons, GSettings schemas and the GTK portal all resolve through
          # XDG_DATA_DIRS; without these the window opens with blank icons and
          # Gio::Settings cannot find Curtail's own schema.
          shellHook = ''
            export GI_TYPELIB_PATH="${typelibPath}"
            export GDK_PIXBUF_MODULE_FILE="${pixbufLoaders}/loaders.cache"
            export XDG_DATA_DIRS="$PWD/tmp/share:${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}:${pkgs.adwaita-icon-theme}/share:$XDG_DATA_DIRS"
            unset BUNDLE_GEMFILE BUNDLE_FROZEN BUNDLE_PATH
            echo "curtail-rb devshell — ruby $(ruby -e 'print RUBY_VERSION')"
            echo "  rake schema           compile the GSettings schema into tmp/share"
            echo "  ./bin/curtail-rb      run the app"
            echo "  rake                  test + lint"
          '';
        };
      });
}
