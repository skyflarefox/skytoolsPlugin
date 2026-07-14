const MILLENNIUM_IS_CLIENT_MODULE = true;
const pluginName = "skytools-plugin";

(window.PLUGIN_LIST ||= {})[pluginName] ||= {};
window.MILLENNIUM_SIDEBAR_NAVIGATION_PANELS ||= {};

async function defaultEntryPoint() {
  return undefined;
}

Object.assign(window.PLUGIN_LIST[pluginName], {
  default: defaultEntryPoint,
  __millennium_internal_plugin_name_do_not_use_or_change__: pluginName
});
