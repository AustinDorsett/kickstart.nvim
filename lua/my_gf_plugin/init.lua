local M = {}

local replacements_file = vim.fn.stdpath('data') .. '/replacements.json'

-- Function to clean GitHub URLs
local function clean_github_url(original, url)
    if string.match(original, "github.com") then
        -- Remove 'blob/branch' part from the URL
        url = url:gsub("/blob/[^/]+/", "/")
    end
    return url
end

-- Function to get all Git repositories and their remote URLs
local function get_git_repos()
    local repos = {}
    -- Find all .git directories
    local handle = io.popen("find ~ -type d -name '.git'")
    if handle then
        for git_dir in handle:lines() do
            -- Get the parent directory of the .git directory
            local repo_dir = git_dir:match("(.*/).git")
            if repo_dir then
                -- Get the remote URL
                local handle_remote = io.popen("cd " .. repo_dir .. " && git remote get-url origin 2>/dev/null")
                if handle_remote then
                    local remote_url = handle_remote:read("*l")
                    handle_remote:close()
                    if remote_url then
                        -- Convert SSH to HTTPS if needed
                        if remote_url:match("^git@") then
                            remote_url = remote_url:gsub(":", "/")
                            remote_url = remote_url:gsub("^git@", "https://")
                        end
                        -- Remove .git from the end of the URL if present
                        remote_url = remote_url:gsub("%.git$", "")
                        repo_dir = repo_dir:gsub("/$", "")
                        repos[remote_url] = repo_dir
                    end
                end
            end
        end
        handle:close()
    end
    return repos
end

-- Configuration: mapping from patterns to replacements
local replacements = {}

-- Function to save replacements to a file
local function save_replacements()
    local file = io.open(replacements_file, "w")
    if file then
        file:write(vim.fn.json_encode(replacements))
        file:close()
    end
end

-- Function to load replacements from a file
local function load_replacements()
    local file = io.open(replacements_file, "r")
    if file then
        local content = file:read("*a")
        replacements = vim.fn.json_decode(content)
        file:close()
    end
end

local function update_replacements()
    replacements = get_git_repos()
    save_replacements()
    print("Replacements updated:")
    for pattern, replacement in pairs(replacements) do
        print(pattern .. " -> " .. replacement)
    end
end

local function escape_lua_pattern(s)
    local matches = { "%", ".", "+", "-", "*", "?", "[", "^", "$", "(", ")", "{", "}", "|" }
    for i = 1, #matches do
        local match = matches[i]
        s = s:gsub("%" .. match, "%%" .. match)
    end
    return s
end

local function replace_path(path)
    for pattern, replacement in pairs(replacements) do
        local escaped_pattern = escape_lua_pattern(pattern)
        if string.find(path, escaped_pattern) then
            print("Replacing " .. pattern .. " with " .. replacement)
            return string.gsub(path, escaped_pattern, replacement)
        end
    end
    return path
end

-- Override the 'gf' behavior
function M.override_gf()
    local current_file = vim.fn.expand("<cfile>")
    local new_file = replace_path(current_file)
    new_file = clean_github_url(current_file, new_file)
    vim.cmd("edit " .. new_file)
end

function M.setup()
    load_replacements()
    vim.api.nvim_set_keymap('n', 'gf', ':lua require("my_gf_plugin").override_gf()<CR>', { noremap = true, silent = true })
    vim.api.nvim_create_user_command('Gfgit', function()
        update_replacements()
    end, {})
end
return M

