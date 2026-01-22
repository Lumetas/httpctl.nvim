local ok, cmp = pcall(require, "cmp")
if ok then
	-- add ht completion, if nvim-cmp is installed
	cmp.register_source("ht", require("ht.extension.ht-cmp").new())
	cmp.setup.filetype({ "ht", "http" }, {
		sources = cmp.config.sources({
			{ name = "ht" },
			{ name = "buffer" },
			{ name = "text" },
			{ name = "path" },
		}),
	})
end
