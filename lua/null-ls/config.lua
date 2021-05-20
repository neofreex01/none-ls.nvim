local autocommands = require("null-ls.autocommands")

local validate = vim.validate

local defaults = {
    debounce = 250,
    on_attach = nil,
    generators = {},
    filetypes = {},
    names = {}
}

local config = vim.deepcopy(defaults)

local register_filetypes = function(filetypes)
    for _, filetype in pairs(filetypes) do
        if not vim.tbl_contains(config.filetypes, filetype) then
            table.insert(config.filetypes, filetype)
        end
    end
end

local register_source = function(source, filetypes, name)
    -- allow plugins to call register multiple times without duplicating sources
    if name then
        if vim.tbl_contains(config.names, name) then return end
        table.insert(config.names, name)
    end

    local method, generator = source.method, source.generator
    filetypes = filetypes or source.filetypes

    validate({
        method = {method, "string"},
        generator = {generator, "table"},
        filetypes = {filetypes, "table"},
        name = {name, "string", true}
    })

    local fn, async = generator.fn, generator.async
    validate({fn = {fn, "function"}, async = {async, "boolean", true}})

    if not config.generators[method] then config.generators[method] = {} end
    register_filetypes(filetypes)

    generator.filetypes = filetypes
    table.insert(config.generators[method], generator)

    -- plugins that register sources after BufEnter may need to call try_attach() again,
    -- after filetypes have been registered
    autocommands.trigger(autocommands.names.REGISTERED)
end

local register = function(to_register)
    -- register a single source
    if to_register.method then
        register_source(to_register)
        return
    end

    -- register a simple list of sources
    if not to_register.sources then
        for _, source in pairs(to_register) do register_source(source) end
        return
    end

    -- register multiple sources with shared configuration
    local sources, filetypes, name = to_register.sources, to_register.filetypes,
                                     to_register.name
    validate({sources = {sources, "table"}})

    for _, source in pairs(sources) do
        register_source(source, filetypes, name)
    end
end

local M = {}

M.get = function() return config end

M.reset = function() config = vim.deepcopy(defaults) end

M.register = register

M.reset_sources = function() config.generators = {} end

M.generators = function(method)
    if method then return config.generators[method] end
    return config.generators
end

M.setup = function(user_config)
    local on_attach, debounce, user_sources = user_config.on_attach,
                                              user_config.debounce,
                                              user_config.sources

    validate({
        on_attach = {on_attach, "function", true},
        debounce = {debounce, "number", true},
        sources = {user_sources, "table", true}
    })

    if on_attach then config.on_attach = on_attach end
    if debounce then config.debounce = debounce end
    if user_sources then register(user_sources) end
end

return M