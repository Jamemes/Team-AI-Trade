Hooks:Add("LocalizationManagerPostInit", "Team_AI_Trade.LocalizationManagerPostInit", function(self, ...)
	LocalizationManager:add_localized_strings({
		hud_ai_traded_in = 'Traded by AI in',
	})

	if Idstring("russian"):key() == SystemInfo:language():key() then
		LocalizationManager:add_localized_strings({
			hud_ai_traded_in = 'Будет совершен обмен напарником через:',
		})
	end
end)

function HUDPlayerCustody:set_respawn_type(is_ai_trade)
	if self._last_respawn_type_is_ai_trade ~= is_ai_trade then
		local text = utf8.to_upper(managers.localization:text(is_ai_trade and "hud_ai_traded_in" or "hud_respawning_in"))
		self._hud_panel:child("custody_panel"):child("timer_msg"):set_text(text)
		self._last_respawn_type_is_ai_trade = is_ai_trade
	end
end