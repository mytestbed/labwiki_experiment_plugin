# labwiki_experiment_plugin

A plugin for Labwiki to prepare, execute, and monitor OMF experiments.

## iBook Widget

This plugin also provides support for creating iBook widgets to run specific
experiments and later interact with them.

At the moment , the only way to create an iBook widget is via a Rake task.

    % rake -T
    rake create_iwidget[host,url,width,height]  # Create an iWidget - host, url, width[640], height[480]
    ....

An example would be ('width' and 'height' are optional):

    % rake create_iwidget[http://192.168.1.2:4000,git:default:repo/oidl/simple_oml_test.rb]
    Creating /Users/max/src/omf_labwiki_experiment/build/git_default_repo_oidl_simple_oml_test_rb.wdgt

This creates a 'git_default_repo_oidl_simple_oml_test_rb.wdgt' in 'build'. Simply drag that directory
onto *iBooks Author*.


