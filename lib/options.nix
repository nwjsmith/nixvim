{
  lib,
  nixvimTypes,
  nixvimUtils,
}:
with lib;
with nixvimUtils;
rec {
  # Creates an option with a nullable type that defaults to null.
  mkNullOrOption =
    type: desc:
    lib.mkOption {
      type = lib.types.nullOr type;
      default = null;
      description = desc;
    };

  mkCompositeOption = desc: options: mkNullOrOption (types.submodule { inherit options; }) desc;

  mkNullOrStr = mkNullOrOption (with nixvimTypes; maybeRaw str);

  mkNullOrLua =
    desc:
    lib.mkOption {
      type = lib.types.nullOr nixvimTypes.strLua;
      default = null;
      description = desc;
      apply = mkRaw;
    };

  mkNullOrLuaFn =
    desc:
    lib.mkOption {
      type = lib.types.nullOr nixvimTypes.strLuaFn;
      default = null;
      description = desc;
      apply = mkRaw;
    };

  mkNullOrStrLuaOr =
    ty: desc:
    lib.mkOption {
      type = lib.types.nullOr (types.either nixvimTypes.strLua ty);
      default = null;
      description = desc;
      apply = v: if builtins.isString v then mkRaw v else v;
    };

  mkNullOrStrLuaFnOr =
    ty: desc:
    lib.mkOption {
      type = lib.types.nullOr (types.either nixvimTypes.strLuaFn ty);
      default = null;
      description = desc;
      apply = v: if builtins.isString v then mkRaw v else v;
    };

  defaultNullOpts = rec {
    # Description helpers
    mkDefaultDesc =
      defaultValue:
      let
        default =
          # Assume a string default is already formatted as intended,
          # historically strings were the only type accepted here.
          # TODO consider deprecating this behavior so we can properly quote strings
          if isString defaultValue then defaultValue else generators.toPretty { } defaultValue;
      in
      "Plugin default:"
      + (
        # Detect whether `default` is multiline or inline:
        if hasInfix "\n" default then "\n\n```nix\n${default}\n```" else " `${default}`"
      );

    mkDesc =
      default: desc:
      let
        defaultDesc = mkDefaultDesc default;
      in
      if desc == "" then
        defaultDesc
      else
        ''
          ${desc}

          ${defaultDesc}
        '';

    mkNullable =
      type: default: desc:
      mkNullOrOption type (mkDesc default desc);

    mkNullableWithRaw = type: mkNullable (nixvimTypes.maybeRaw type);

    mkStrLuaOr =
      type: default: desc:
      mkNullOrStrLuaOr type (mkDesc default desc);

    mkStrLuaFnOr =
      type: default: desc:
      mkNullOrStrLuaFnOr type (mkDesc default desc);

    mkLua = default: desc: mkNullOrLua (mkDesc default desc);

    mkLuaFn = default: desc: mkNullOrLuaFn (mkDesc default desc);

    mkNum = mkNullableWithRaw types.number;
    mkInt = mkNullableWithRaw types.int;
    # Positive: >0
    mkPositiveInt = mkNullableWithRaw types.ints.positive;
    # Unsigned: >=0
    mkUnsignedInt = mkNullableWithRaw types.ints.unsigned;
    mkBool = mkNullableWithRaw types.bool;
    mkStr =
      # TODO we should delegate rendering quoted string to `mkDefaultDesc`,
      # once we remove its special case for strings.
      default:
      assert default == null || isString default;
      mkNullableWithRaw types.str (generators.toPretty { } default);
    mkAttributeSet = mkNullable nixvimTypes.attrs;
    mkListOf = ty: default: mkNullable (with nixvimTypes; listOf (maybeRaw ty)) default;
    mkAttrsOf = ty: default: mkNullable (with nixvimTypes; attrsOf (maybeRaw ty)) default;
    mkEnum =
      enumValues: default:
      mkNullableWithRaw (types.enum enumValues) (
        # TODO we should remove this once `mkDefaultDesc` no longer has a special case
        if isString default then generators.toPretty { } default else default
      );
    mkEnumFirstDefault = enumValues: mkEnum enumValues (head enumValues);
    mkBorder =
      default: name: desc:
      mkNullableWithRaw nixvimTypes.border default (
        let
          defaultDesc = ''
            Defines the border to use for ${name}.
            Accepts same border values as `nvim_open_win()`. See `:help nvim_open_win()` for more info.
          '';
        in
        if desc == "" then
          defaultDesc
        else
          ''
            ${desc}
            ${defaultDesc}
          ''
      );
    mkSeverity =
      default: desc:
      mkOption {
        type =
          with types;
          nullOr (
            either ints.unsigned (enum [
              "error"
              "warn"
              "info"
              "hint"
            ])
          );
        default = null;
        apply = mapNullable (
          value: if isInt value then value else mkRaw "vim.diagnostic.severity.${strings.toUpper value}"
        );
        description = mkDesc default desc;
      };
    mkLogLevel =
      default: desc:
      mkOption {
        type = with types; nullOr (either ints.unsigned nixvimTypes.logLevel);
        default = null;
        apply = mapNullable (
          value: if isInt value then value else mkRaw "vim.log.levels.${strings.toUpper value}"
        );
        description = mkDesc default desc;
      };

    mkHighlight =
      default: name: desc:
      mkNullable nixvimTypes.highlight default (if desc == "" then "Highlight settings." else desc);
  };

  mkPackageOption =
    {
      name ? null, # Can be null if a custom description is given.
      default,
      description ? null,
      example ? null,
    }:
    mkOption {
      type = with types; nullOr package;
      inherit default example;
      description =
        if description == null then
          ''
            Which package to use for `${name}`.
            Set to `null` to disable its automatic installation.
          ''
        else
          description;
    };

  mkPluginPackageOption =
    name: default:
    mkOption {
      type = types.package;
      inherit default;
      description = "Which package to use for the ${name} plugin.";
    };

  mkSettingsOption =
    {
      options ? { },
      description,
      example ? null,
    }:
    mkOption {
      type =
        with types;
        submodule {
          freeformType = attrsOf anything;
          inherit options;
        };
      default = { };
      inherit description;
      example =
        if example == null then
          {
            foo_bar = 42;
            hostname = "localhost:8080";
            callback.__raw = ''
              function()
                print('nixvim')
              end
            '';
          }
        else
          example;
    };
}
