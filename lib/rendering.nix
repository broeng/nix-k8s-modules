{
  pkgs,
  lib,
  k8slib,
  openapi2jsonschema,
  # Checkout of https://github.com/datreeio/CRDs-catalog used by validate-crd
  crdsCatalog,
  # Directory (relative to where the script is run) for generated values files
  valuesDir ? "docs/generated-values",
  # Directory (relative to where the script is run) for generated CRD schemas
  crdSchemasDir ? "docs/generated-crd-schemas",
  ...
}:
rec {

  forEachEnv =
    fn: env: conf:
    lib.mapAttrsToList (app: appConf: fn env app appConf) conf.applications;
  forEachApplication =
    appsByEnv: fn:
    lib.listToAttrs (
      lib.flatten (lib.flatten (lib.mapAttrsToList (env: envConf: forEachEnv fn env envConf) appsByEnv))
    );
  forEachApplicationAsList =
    appsByEnv: fn:
    lib.flatten (lib.flatten (lib.mapAttrsToList (env: envConf: forEachEnv fn env envConf) appsByEnv));

  makeRendererPackages =
    appsByEnv:
    forEachApplication appsByEnv (
      env: app: conf:
      lib.nameValuePair "render-${app}-${env}" (
        pkgs.writeShellScriptBin "render-${app}-${env}" ''
          ${pkgs.coreutils}/bin/cat ${conf.out}
        ''
      )
    );

  makePackageDependenciesRenderer =
    appsByEnv:
    forEachApplication appsByEnv (
      env: app: conf:
      lib.nameValuePair "render-dependencies-${app}-${env}" (
        pkgs.writeShellScriptBin "render-dependencies-${app}-${env}" ''
          ${pkgs.coreutils}/bin/cat ${conf.dependencies.yamlOut}
        ''
      )
    );

  makePackageOnlyRenderer =
    appsByEnv:
    forEachApplication appsByEnv (
      env: app: conf:
      lib.nameValuePair "render-no-deps-${app}-${env}" (
        pkgs.writeShellScriptBin "render-no-deps-${app}-${env}" ''
          ${pkgs.coreutils}/bin/cat ${conf.application.yamlOut}
        ''
      )
    );

  makeRenderAll =
    appsByEnv:
    let
      failedAssertions = lib.filter (a: !a.assertion) (
        lib.flatten (lib.mapAttrsToList (env: conf: conf.assertions) appsByEnv)
      );
    in
    {
      "render-all" = pkgs.writeShellScriptBin "render-all" (
        lib.concatStringsSep "\n" (
          (lib.map (a: ''
            echo "${a.message}"
          '') failedAssertions)
          ++ (lib.optional (failedAssertions != [ ]) "exit 1")
          ++ (lib.flatten (
            lib.flatten (
              lib.mapAttrsToList (
                env: envConf:
                lib.map (conf: ''
                  echo "---"
                  ${pkgs.coreutils}/bin/cat ${conf.out}
                '') envConf.k8s.environment.applications
              ) appsByEnv
            )
          ))
        )
      );
    };

  makeChartValuesRenderer =
    appsByEnv:
    forEachApplication appsByEnv (
      env: app: conf:
      lib.map (
        chart:
        lib.nameValuePair "values-${chart.name}-${env}" (
          pkgs.writeShellScriptBin "values-${chart.name}-${env}" ''
            ${pkgs.coreutils}/bin/cat ${chart.renderedDefaultValues}
          ''
        )
      ) (conf.dependencies.charts ++ conf.application.charts)
    );

  makeChartValuesRenderAll = appsByEnv: {
    "values-generate-all" = pkgs.writeShellScriptBin "values-generate-all" (
      lib.concatStringsSep "\n" (
        (lib.flatten (
          forEachApplicationAsList appsByEnv (
            env: app: conf:
            # we can ignore env hereafter, as we just extract the default values from each chart
            lib.map (chart: ''
              OUTDIR="${valuesDir}/${chart.name}"
              ${pkgs.coreutils}/bin/mkdir -p $OUTDIR
              ${pkgs.coreutils}/bin/cat ${chart.valuesTemplates.renderedDefaultValues} > $OUTDIR/values.yaml
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (subchart: valuesFile: ''
                  ${pkgs.coreutils}/bin/mkdir -p $OUTDIR/${subchart}
                  ${pkgs.coreutils}/bin/cat ${valuesFile} > $OUTDIR/${subchart}/values.yaml
                '') chart.valuesTemplates.renderedSubChartValues
              )}
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (var: v: ''
                  ${pkgs.coreutils}/bin/cat ${k8slib.yaml.writeFile v} > $OUTDIR/${var}
                '') chart.valuesTemplates.variables
              )}
              echo "Generated values available at: $OUTDIR"
            '') (conf.dependencies.charts ++ conf.application.charts)
          )
        ))
        ++ [
          ''
            echo ""
            ${pkgs.git}/bin/git status ${valuesDir}
            echo ""
            echo "Please review if there's any changes we need to adapt to."
          ''
        ]
      )
    );
  };

  makeCRDSchemasAll = appsByEnv: {
    "crd-schemas-generate-all" = pkgs.writeShellScriptBin "crd-schemas-generate-all" ''
      TEMPFILE=$(${pkgs.coreutils}/bin/mktemp)
      ${(makeRenderAll appsByEnv).render-all}/bin/render-all > $TEMPFILE
      mkdir -p ${crdSchemasDir}
      cd ${crdSchemasDir}
      export FILENAME_FORMAT="{fullgroup}_{kind}_{version}"
      ${openapi2jsonschema}/bin/openapi2jsonschema $TEMPFILE
    '';
  };

  makeCRDValidate = appsByEnv: {
    "validate-crd" = pkgs.writeShellScriptBin "validate-crd" ''
      TEMPFILE=$(${pkgs.coreutils}/bin/mktemp)
      ${(makeRenderAll appsByEnv).render-all}/bin/render-all > $TEMPFILE
      cat $TEMPFILE | ${pkgs.kubeconform}/bin/kubeconform \
        -schema-location "${crdsCatalog}/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json" \
        -schema-location "${crdSchemasDir}/{{.Group}}_{{.ResourceKind}}_{{.ResourceAPIVersion}}.json" \
        -schema-location "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/refs/heads/master/master-standalone-strict/{{ .ResourceKind }}{{ .KindSuffix }}.json" \
        -skip CustomResourceDefinition \
        -strict \
        -summary
    '';
  };

  makeChartTree =
    appsByEnv:
    let
      chartScripts = forEachApplication appsByEnv (
        env: app: conf:
        lib.nameValuePair "${env}-${app}" (
          lib.concatStringsSep "\n" (
            (lib.flip lib.map conf.dependencies.charts (c: ''
              ${pkgs.coreutils}/bin/mkdir -p $out/${env}/${app}/dependencies
              ${pkgs.coreutils}/bin/ls -s ${c.chart} $out/${env}/${app}/dependencies/${c.name}
            ''))
            ++ (lib.flip lib.map conf.application.charts (c: ''
              ${pkgs.coreutils}/bin/mkdir -p $out/${env}/${app}/applications
              ${pkgs.coreutils}/bin/ln -s ${c.chart} $out/${env}/${app}/applications/${c.name}
            ''))
          )
        )
      );
    in
    {
      make-chart-tree = pkgs.stdenv.mkDerivation {
        name = "make-chart-tree";
        phases = [ "buildPhase" ];
        buildPhase = lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: v) chartScripts);
      };
    };

}
