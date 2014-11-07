{parser} = require 'bless'
fs = require 'fs'
path = require 'path'
logger = require 'logmimosa'
color = require('ansi-color').set
_ = require 'lodash'
wrench = require 'wrench'
{printObj, trackCompletion} = require './util'

writeFiles = (blessData, input, output) ->
  numFiles = blessData.data.length
  if numFiles > 1 or input isnt output
    _.each blessData.data, (data, index) ->
      name = if index == 0 then  input else input.replace '.css', "-blessed#{index}.css"
      fd = fs.openSync name, 'w'
      fs.writeSync fd, data, 0, 'utf-8'
    logger.success "#{numFiles} CSS files created for #{input}"
  else
    logger.success "No changes made."
 
blessFile = (input, output, options, next) ->
  unless fs.existsSync input
    return logger.warn "mimosa-bless: bless file [[ #{input} ]] does not exist"

  logger.info "Blessing [[ #{input} ]]"

  fs.readFile input, 'utf-8', (e, data) ->
    if (e)
      logger.error "blessc: " + e.message
      return next()

    logger.debug "finished reading file[[ #{input} ]]"

    logger.debug "running bless parser on [[ #{input} ]]"
    blessData = parser data
    numSelectors = blessData.numSelectors
    logger.info "Source CSS file [[ #{input} ]] contained #{numSelectors} selectors"
    next blessData

removeBlessed = (files) ->
  logger.info "Removing blessed assets"
  _ files
    .map (file) ->
      basename = path.basename file, ".css"
      dirname = path.dirname file
      wrench.readdirSyncRecursive(dirname).filter (f) ->
        (new RegExp "#{basename}-blessed\\d\\.css$").test f
      .map (f) -> path.join dirname, f
    .flatten()
    .uniq()
    .each (file) ->
      fs.unlinkSync file

cleanBlessed = (mimosaConfig, options, next) ->
  #TODO: clean up any generated bless files
  next()

checkForBless = (mimosaConfig, options, next) ->
  blessOnWatch = mimosaConfig.bless.blessOnWatch
  isWatch = mimosaConfig.isWatch
  return next() unless blessOnWatch and isWatch
  files = _ options.files
    .map (file) ->
      file.outputFileName
    .uniq()
    .value()

  removeBlessed files
  blessFiles files, mimosaConfig, next

gatherFiles = (filesFromOptions) ->
  _ filesFromOptions
    .map (entry) ->
      if fs.statSync(entry).isDirectory()
      then wrench.readdirSyncRecursive(entry).filter (f) ->
        (path.extname f) == ".css"
      .map (f) -> path.join entry, f
      else [entry]
    .flatten()
    .uniq()
    .value()

blessFiles = (files, config, next) ->
  settings = config.bless.options

  logger.info "Blessing files"

  sources = _.map files, (value, key) ->
    input = if _.isString(key) then key else value
    output = value
    {input, output}

  uniqueInputs = _.map sources, ({input, output}) -> input

  finish = trackCompletion "blessSources", uniqueInputs, next

  _.each sources, ({input, output}) ->
    blessFile input, output, settings, (blessData) ->
      writeFiles blessData, input, output if !!blessData
      finish input

blessAll = (mimosaConfig, options, next) ->
  #TODO: for some reason this goes really slow in watch mode
  #when working with a large code base, need to investigate
  isBuild = mimosaConfig.isBuild
  files = gatherFiles mimosaConfig.bless.files

  blessOnWatch = mimosaConfig.bless.blessOnWatch

  logger.debug "bless files: #{files}"
  logger.debug "blessOnWatch: #{blessOnWatch}"
  logger.debug "isBuild: #{isBuild}"
  unless blessOnWatch or isBuild
    next()
    return

  blessFiles files, mimosaConfig, next

blessCommand = (retrieveConfig) ->
  retrieveConfig false, (config) ->
    config.isBuild = true
    blessAll config, {}, (->)

module.exports = {blessAll, checkForBless, cleanBlessed, blessCommand}
