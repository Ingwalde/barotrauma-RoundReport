local Language = {}

-- Resolve once when scripts load so static labels and report content stay consistent.
-- The client uses its own settings; server-generated chat uses the server settings.
Language.languages = {
    english = "en", ukrainian = "uk", german = "de", french = "fr",
    polish = "pl", russian = "ru", brazilianportuguese = "pt-BR",
    castilianspanish = "es", latinamericanspanish = "es-419",
    turkish = "tr", japanese = "ja", korean = "ko",
    simplifiedchinese = "zh-CN", traditionalchinese = "zh-TW",
}

local function languageCode(value)
    local name = tostring(value):lower()
    for _, code in pairs(Language.languages) do
        if name == code:lower() then return code end
    end
    return Language.languages[name] or "en"
end

function Language.resolveLanguage(configured)
    if configured ~= nil and configured ~= "auto" then
        return languageCode(configured)
    end
    local ok, language = pcall(function()
        return tostring(Game.Settings.CurrentConfig.Language.Value)
    end)
    if ok then return languageCode(language) end
    return "en"
end

return Language
