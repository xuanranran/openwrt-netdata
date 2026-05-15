// SPDX-License-Identifier: Apache-2.0

'use strict';
'require fs';
'require ui';
'require view';

var helper = '/usr/libexec/netdata-luci';
var netdataUrl = 'http://' + window.location.hostname + ':19999';

function parseClaimConfig(output) {
	var config = {};
	var lines = (output || '').split(/\n/);

	for (var i = 0; i < lines.length; i++) {
		var match = lines[i].match(/^([^=]+)=(.*)$/);
		if (match)
			config[match[1]] = match[2];
	}

	return config;
}

function showTab(name) {
	var tabs = document.querySelectorAll('[data-netdata-tab]');
	var panes = document.querySelectorAll('[data-netdata-pane]');

	for (var i = 0; i < tabs.length; i++) {
		var active = tabs[i].getAttribute('data-netdata-tab') == name;
		tabs[i].classList.toggle('active', active);
	}

	for (var j = 0; j < panes.length; j++) {
		var visible = panes[j].getAttribute('data-netdata-pane') == name;
		panes[j].style.display = visible ? '' : 'none';
	}
}

function tabButton(name, label, active) {
	return E('li', { 'class': active ? 'cbi-tab active' : 'cbi-tab' }, [
		E('a', {
			'href': '#',
			'data-netdata-tab': name,
			'click': function(ev) {
				ev.preventDefault();
				showTab(name);
			}
		}, label)
	]);
}

function dashboardFrame(path) {
	return E('iframe', {
		'src': netdataUrl + path,
		'style': 'width: 100%; min-height: 1200px; border: none; border-radius: 3px; resize: vertical;'
	}, null);
}

function saveCloudConfig() {
	var token = document.getElementById('netdata-claim-token').value.trim();
	var rooms = document.getElementById('netdata-claim-rooms').value.trim();

	if (!token || !rooms) {
		ui.addNotification(null, E('p', _('Token and rooms are required.')), 'danger');
		return;
	}

	ui.showModal(_('Saving'), [
		E('p', _('Saving cloud configuration and restarting Netdata...'))
	]);

	return fs.exec(helper, [ 'claim-write', token, rooms ]).then(function(res) {
		if (res.code != 0)
			throw new Error(res.stderr || res.stdout || _('Unable to save cloud configuration.'));

		ui.hideModal();
		ui.addNotification(null, E('p', _('Cloud configuration saved and Netdata restarted.')), 'info');
	}).catch(function(err) {
		ui.hideModal();
		ui.addNotification(null, E('p', err.message), 'danger');
	});
}

function showCloudModal(claim) {
	ui.showModal(_('Cloud Configuration'), [
		E('div', { 'class': 'cbi-section' }, [
			E('div', { 'class': 'cbi-value' }, [
				E('label', { 'class': 'cbi-value-title', 'for': 'netdata-claim-token' }, _('Claim token')),
				E('div', { 'class': 'cbi-value-field' }, [
					E('input', {
						'id': 'netdata-claim-token',
						'type': 'password',
						'class': 'cbi-input-text',
						'value': claim.token || '',
						'placeholder': _('Paste claim token')
					})
				])
			]),
			E('div', { 'class': 'cbi-value' }, [
				E('label', { 'class': 'cbi-value-title', 'for': 'netdata-claim-rooms' }, _('Rooms')),
				E('div', { 'class': 'cbi-value-field' }, [
					E('input', {
						'id': 'netdata-claim-rooms',
						'type': 'text',
						'class': 'cbi-input-text',
						'value': claim.rooms || '',
						'placeholder': _('Paste room id')
					})
				])
			])
		]),
		E('div', { 'class': 'right' }, [
			E('button', {
				'class': 'btn',
				'click': ui.hideModal
			}, _('Cancel')),
			' ',
			E('button', {
				'class': 'btn cbi-button-positive important',
				'click': saveCloudConfig
			}, _('Save & Apply'))
		])
	]);
}

return view.extend({
	load: function() {
		return Promise.all([
			L.resolveDefault(fs.stat('/usr/share/netdata/web/v3/index.html'), null),
			L.resolveDefault(fs.exec(helper, [ 'claim-read' ]), { code: 1, stdout: '' })
		]);
	},

	render: function(data) {
		var hasV3 = data[0] != null;
		var claim = parseClaimConfig(data[1].stdout);

		return E('div', { 'class': 'cbi-map' }, [
			E('h2', { 'name': 'content' }, _('Netdata')),
			E('ul', { 'class': 'cbi-tabmenu' }, [
				tabButton('status', _('Status'), true),
				hasV3 ? tabButton('v3', _('V3 Dashboard'), false) : '',
				tabButton('cloud', _('Cloud Configuration'), false)
			]),
			E('div', { 'class': 'cbi-section', 'data-netdata-pane': 'status' }, [
				dashboardFrame('/v1/')
			]),
			hasV3 ? E('div', {
				'class': 'cbi-section',
				'data-netdata-pane': 'v3',
				'style': 'display:none'
			}, [
				dashboardFrame('/v3/')
			]) : '',
			E('div', {
				'class': 'cbi-section',
				'data-netdata-pane': 'cloud',
				'style': 'display:none'
			}, [
				E('h3', _('Netdata Cloud')),
				E('p', _('Configure the claim token and room id stored in /etc/netdata/claim.conf.')),
				E('div', { 'class': 'table cbi-section-table' }, [
					E('div', { 'class': 'tr cbi-section-table-row' }, [
						E('div', { 'class': 'td left' }, _('Cloud URL')),
						E('div', { 'class': 'td left' }, claim.url || 'https://app.netdata.cloud')
					]),
					E('div', { 'class': 'tr cbi-section-table-row' }, [
						E('div', { 'class': 'td left' }, _('Claim token')),
						E('div', { 'class': 'td left' }, claim.token ? _('Configured') : _('Not configured'))
					]),
					E('div', { 'class': 'tr cbi-section-table-row' }, [
						E('div', { 'class': 'td left' }, _('Rooms')),
						E('div', { 'class': 'td left' }, claim.rooms || _('Not configured'))
					])
				]),
				E('button', {
					'class': 'btn cbi-button-positive important',
					'click': function() {
						showCloudModal(claim);
					}
				}, _('Edit Cloud Configuration'))
			])
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
