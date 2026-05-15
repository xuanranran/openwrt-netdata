// SPDX-License-Identifier: Apache-2.0

'use strict';
'require view';

return view.extend({
	render() {
		const origin = 'http://' + window.location.hostname + ':19999';

		return E('div', {'class': 'cbi-map' }, [
			E('h2', {'name': 'content'}, [
				_('Netdata Dashboard')
			]),
			E('div', {
				'style': 'display: flex; gap: 8px; align-items: center; margin: 0 0 12px 0;'
			}, [
				E('a', {
					'class': 'btn cbi-button cbi-button-action',
					'href': origin + '/v3/',
					'target': '_blank',
					'rel': 'noopener noreferrer'
				}, _('Open V3 Dashboard')),
				E('a', {
					'class': 'btn cbi-button',
					'href': origin + '/',
					'target': '_blank',
					'rel': 'noopener noreferrer'
				}, _('Open Dashboard'))
			]),
			E('iframe', {
				'src': origin + '/v3/',
				'style': 'width: 100%; min-height: 1200px; border: none; border-radius: 3px; resize: vertical;'
			}, null)
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
