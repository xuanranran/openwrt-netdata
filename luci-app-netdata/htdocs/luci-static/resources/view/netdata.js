// SPDX-License-Identifier: Apache-2.0

'use strict';
'require poll';
'require rpc';
'require view';

var callServiceList = rpc.declare({
	object: 'service',
	method: 'list',
	params: ['name'],
	expect: { '': {} }
});

function getServiceStatus() {
	return L.resolveDefault(callServiceList('netdata'), {}).then(function(res) {
		var instances = {};

		try {
			instances = res.netdata.instances || {};
		} catch (e) {}

		return Object.keys(instances).some(function(name) {
			return instances[name].running === true;
		});
	});
}

function renderStatus(isRunning, url) {
	var state = isRunning
		? '<span style="color:green"><strong>%s</strong></span>'.format(_('RUNNING'))
		: '<span style="color:red"><strong>%s</strong></span>'.format(_('NOT RUNNING'));

	return '%s: %s&#160;&#160;<a class="btn cbi-button" href="%h" target="_blank" rel="noreferrer noopener">%s</a>'.format(
		_('Netdata service'),
		state,
		url,
		_('Open dashboard')
	);
}

return view.extend({
	render: function() {
		var url = 'http://' + window.location.hostname + ':19999/';

		poll.add(function() {
			return getServiceStatus().then(function(isRunning) {
				var status = document.getElementById('netdata_status');

				if (status)
					status.innerHTML = renderStatus(isRunning, url);
			});
		});

		return E('div', { 'class': 'cbi-map' }, [
			E('h2', { 'name': 'content' }, [
				_('Netdata Dashboard')
			]),
			E('div', { 'class': 'cbi-section' }, [
				E('p', { 'id': 'netdata_status' }, _('Collecting data...'))
			]),
			E('iframe', {
				'src': url,
				'style': 'width: 100%; min-height: 1200px; border: none; border-radius: 3px; resize: vertical;'
			}, null)
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
