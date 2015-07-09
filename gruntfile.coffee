###
Define tasks.
###
module.exports = (grunt) ->

  config = grunt.file.readJSON('config.json')

  grunt.initConfig

    ###
    Build banner.
    ###
    banner: "/* Widget compiled at #{new Date().toUTCString()} */\n"

    ###
    Compile stylesheets.
    ###
    compass:
      options:
        cssDir: 'build/resources/css'
        sassDir: 'resources/scss'
        imagesDir: 'resources/images'
        fontsDir: 'resources/fonts'
        outputStyle: 'compressed'
        force: true
        importPath: ['node_modules/bootstrap-sass/assets/stylesheets', 'node_modules/bootstrap-sass/assets/stylesheets/bootstrap']
      watch:
        options:
          watch: true
      compile:
        options:
          httpPath: config.widget.cdn
          relativeAssets: false

    ###
    Compile widget.
    ###
    browserify:
      compile:
        options:
          extension: ['.coffee', '.js']
          transform: ['coffeeify', 'debowerify', 'deglobalify', 'jstify']
          external: ['jquery']
          ignore: ['underscore']
          standalone: 'RingCaptcha'
          postBundleCB: (err, src, next) ->
            if (src)
              src = '(function (jQuery) { ' + src + ' })(window.jQuery);'
            next(err, src)
        files:
          'build/bundle.js': ['index.coffee']

    ###
    Uglify compiled code.
    ###
    uglify:
      options:
        banner: "<%= banner %>"
        preserveComments: false
      build:
        files:
          'build/bundle.min.js': ['build/bundle.js']

    ###
    Copy.
    ###
    copy:
      resources:
        files: [
          { expand: true, src: ['resources/fonts/**'], dest: 'build' }
          { expand: true, src: ['resources/images/**'], dest: 'build' }
        ]
      translations:
        files: [
          { expand: true, src: ['resources/locales/**/*.json'], dest: 'build' }
        ]
        options:
          process: (content, srcpath) ->
            jsonminify = require('jsonminify')
            return jsonminify(content)

    ###
    Watch changes.
    ###
    watch:
      options:
        atBegin: true
      coffee:
        files: ['index.coffee', 'src/**/*.coffee']
        tasks: ['browserify:compile', 'uglify:build']
      resources:
        files: ['resources/!{scss,views}/**']
        tasks: ['copy:translations', 'copy:resources']

    ###
    Upload build files to S3
    ###
    s3:
      options:
        key: config.aws.key
        secret: config.aws.secret
        region: config.aws.region
        access: 'public-read'
        headers:
          'Cache-Control': 'max-age=3600'
      production:
        options:
          bucket: config.aws.s3.bucket
        sync: [
          src: 'build/**'
          dest: config.aws.s3.path
          rel: 'build'
          options:
            verify: true
        ]

    ###
    Invalidate CDN cache
    ###
    invalidate_cloudfront:
      options:
        key: config.aws.key,
        secret: config.aws.secret,
        distribution: config.aws.distribution
      production:
        files: [
          { expand: true, cwd: './build/', src: ['**/*'], filter: 'isFile', dest: config.aws.s3.path }
        ]

  grunt.loadNpmTasks 'grunt-browserify'
  grunt.loadNpmTasks 'grunt-contrib-compass'
  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.loadNpmTasks 'grunt-contrib-uglify'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-s3'
  grunt.loadNpmTasks 'grunt-invalidate-cloudfront'

  grunt.registerTask 'build', ['browserify:compile', 'uglify:build', 'copy', 'compass:compile']

