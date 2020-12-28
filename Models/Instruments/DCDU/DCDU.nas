# A3XX DCDU

# Copyright (c) 2020 Josh Davidson (Octal450)

var DCDU = nil;
var DCDU_test = nil;
var DCDU_display = nil;
var et = 0;
var acconfig = props.globals.getNode("/systems/acconfig/autoconfig-running", 1);

# props.nas nodes
var dcdu_rate = props.globals.getNode("/systems/acconfig/options/dcdu-rate", 1);

var dcdu_test = props.globals.initNode("/instrumentation/du/dcdu-test", 0, "BOOL");
var dcdu_test_time = props.globals.initNode("/instrumentation/du/dcdu-test-time", 0.0, "DOUBLE");
var dcdu_offtime = props.globals.initNode("/instrumentation/du/dcdu-off-time", 0.0, "DOUBLE");
var dcdu_test_amount = props.globals.initNode("/instrumentation/du/dcdu-test-amount", 0.0, "DOUBLE");

# todo 16.5 watts

var canvas_DCDU_base = {
	init: func(canvas_group, file) {
		var font_mapper = func(family, weight) {
			return "LiberationMonoCustom.ttf";
		};
		
		canvas.parsesvg(canvas_group, file, {"font-mapper": font_mapper});
		
		var svg_keys = me.getKeys();
		foreach(var key; svg_keys) {
			me[key] = canvas_group.getElementById(key);
			var svg_keys = me.getKeys();

			foreach (var key; svg_keys) {
				me[key] = canvas_group.getElementById(key);

				var clip_el = canvas_group.getElementById(key ~ "_clip");
				if (clip_el != nil) {
					clip_el.setVisible(0);
					var tran_rect = clip_el.getTransformedBounds();

					var clip_rect = sprintf("rect(%d,%d, %d,%d)", 
					tran_rect[1], # 0 ys
					tran_rect[2], # 1 xe
					tran_rect[3], # 2 ye
					tran_rect[0]); #3 xs
					#   coordinates are top,right,bottom,left (ys, xe, ye, xs) ref: l621 of simgear/canvas/CanvasElement.cxx
					me[key].set("clip", clip_rect);
					me[key].set("clip-frame", canvas.Element.PARENT);
				}
			}
		}
		me.page = canvas_group;
		
		return me;
	},
	getKeys: func() {
		return [];
	},
	updateTest: func() {
		if (systems.ELEC.Bus.dc1.getValue() >= 25 or systems.ELEC.Bus.ac1.getValue() >= 110) {
			if (dcdu_offtime.getValue() + 3 < et) { 
				if (pts.Gear.wow[0].getValue() == 1) {
					if (acconfig.getValue() != 1 and dcdu_test.getValue() != 1) {
						dcdu_test.setValue(1);
						dcdu_test_amount.setValue(math.round((rand() * 5 ) + 25, 0.1));
						dcdu_test_time.setValue(et);
					} else if (acconfig.getValue() == 1 and dcdu_test.getValue() != 1) {
						dcdu_test.setValue(1);
						dcdu_test_amount.setValue(math.round((rand() * 5 ) + 25, 0.1));
						dcdu_test_time.setValue(et - 20);
					}
				} else {
					dcdu_test.setValue(1);
					dcdu_test_amount.setValue(0);
					dcdu_test_time.setValue(-100);
				}
			}
		} else {
			dcdu_test.setValue(0);
			dcdu_offtime.setValue(et);
		}
	},
	update: func() {
		et = pts.Sim.Time.elapsedSec.getValue();
		if (systems.ELEC.Bus.dc1.getValue() >= 25 or systems.ELEC.Bus.ac1.getValue() >= 110) {
			if (dcdu_test_time.getValue() + dcdu_test_amount.getValue() >= et) {
				DCDU.page.hide();
				DCDU_test.page.show();
			} else {
				DCDU.page.show();
				DCDU_test.page.hide();
				DCDU.update();
			}
		} else {
			DCDU.page.hide();
			DCDU_test.page.hide();
		}
	},
};

var CPDLCstatusNode = props.globals.getNode("/network/cpdlc/link/status");
var CPDLCauthority = props.globals.getNode("/network/cpdlc/link/data-authority");

var canvas_DCDU = {
	showingMessage: 0,
	new: func(canvas_group, file) {
		var m = {parents: [canvas_DCDU, canvas_DCDU_base]};
		m.init(canvas_group, file);
		m.updateActiveATC();
		m["MessageTimeStamp"].hide();
		m["Close"].hide();
		return m;
	},
	getKeys: func() {
		return ["ActiveATC","MessageTimeStamp","ADSConnection","RecallMode","LinkLost","Recall","Close"];
	},
	cache: {
		adsCount: 0,
	},
	currentMessage: nil,
	update: func() {
		me["RecallMode"].hide();
		me["LinkLost"].hide();
		me["Recall"].hide();
		
		if (!me.showingMessage) {
			if (atsu.ADS.getCount() != me.cache.adsCount) {
				me.cache.adsCount = atsu.ADS.getCount();
				# FANS A+: status of ADS seems to be independent of connection to CPDLC: confirm in GTG document
				if (atsu.ADS.state == 2) {
					me["ADSConnection"].setText("ADS CONNECTED(" ~ atsu.ADS.getCount() ~ ")");
					me["ADSConnection"].show();
				} else {
					me["ADSConnection"].hide();
				}
			}
		} else {
			me["ADSConnection"].hide();
		}
	},
	showNextMessage: func() {
		me.showingMessage = 1;
		me.currentMessage = atsu.DCDUBuffer.popMessage();
		me["MessageTimeStamp"].show();
		me["MessageTimeStamp"].setText(me.currentMessage.receivedTime ~ " FROM " ~ CPDLCauthority.getValue() ~ " CTL");
		me["ActiveATC"].hide();
		me["Close"].show();
	},
	clearMessage: func() {
		if (me.showingMessage) {
			me.currentMessage = nil;
			me["MessageTimeStamp"].hide();
			me["Close"].hide();
			me.updateActiveATC();
			me.showingMessage = 0;
		}
	},
	updateActiveATC: func() {
		if (CPDLCstatusNode.getValue() == 2) {
			me["ActiveATC"].setText("ACTIVE ATC : " ~ CPDLCauthority.getValue() ~ " CTL");
			me["ActiveATC"].show();
		} else {
			me["ActiveATC"].hide();
		}
	},
	btnL1: func() {
	
	},
	btnL2: func() {
	
	},
	btnR1: func() {
	
	},
	btnR2: func() {
		if (me.showingMessage) {
			me.clearMessage();
		}
	},
};

setlistener("/network/cpdlc/link/status", func() {
	if (DCDU != nil) {
		DCDU.updateActiveATC();
	}
}, 0, 0);

setlistener("/network/cpdlc/link/data-authority", func() {
	if (DCDU != nil) {
		DCDU.updateActiveATC();
	}
}, 0, 0);

var canvas_DCDU_test = {
	init: func(canvas_group, file) {
		var font_mapper = func(family, weight) {
			return "LiberationFonts/LiberationSans-Regular.ttf";
		};

		canvas.parsesvg(canvas_group, file, {"font-mapper": font_mapper});
		
		var svg_keys = me.getKeys();
		foreach(var key; svg_keys) {
			me[key] = canvas_group.getElementById(key);
		}

		me.page = canvas_group;

		return me;
	},
	new: func(canvas_group, file) {
		var m = {parents: [canvas_DCDU_test]};
		m.init(canvas_group, file);

		return m;
	},
	getKeys: func() {
		return ["Test_white","Test_text"];
	},
};

setlistener("sim/signals/fdm-initialized", func {
	DCDU_display = canvas.new({
		"name": "DCDU",
		"size": [766, 512],
		"view": [766, 512],
		"mipmapping": 1
	});
	DCDU_display.addPlacement({"node": "dcduScreenL"});
	DCDU_display.addPlacement({"node": "dcduScreenR"});
	var group_DCDU = DCDU_display.createGroup();
	var group_DCDU_test = DCDU_display.createGroup();
	
	
	DCDU = canvas_DCDU.new(group_DCDU, "Aircraft/A320-family/Models/Instruments/DCDU/DCDU.svg");
	DCDU_test = canvas_DCDU_test.new(group_DCDU_test, "Aircraft/A320-family/Models/Instruments/DCDU/DCDU-test.svg");
	
	DCDU_update.start();
	if (dcdu_rate.getValue() > 1) {
		rateApply();
	}
});

var rateApply = func {
	DCDU_update.restart(0.15 * dcdu_rate.getValue());
}

var DCDU_update = maketimer(0.15, func {
	canvas_DCDU_base.update();
});

setlistener("/systems/electrical/bus/dc-1", func() {
	canvas_DCDU_base.updateTest();
}, 0, 0);

setlistener("/systems/electrical/bus/ac-1", func() {
	canvas_DCDU_base.updateTest();
}, 0, 0);

var showDCDU = func {
	var dlg = canvas.Window.new([383, 256], "dialog").set("resize", 1);
	dlg.setCanvas(DCDU_display);
}
