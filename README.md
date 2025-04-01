items for core 

['wagonrepairkit'] = {['name'] = 'wagonrepairkit', ['label'] = 'wagonrepairkit', ['weight'] = 5, ['type'] = 'item', ['image'] = 'wagonrepairkit.png', ['unique'] = false, ['useable'] = true, ['shouldClose'] = true, ['combinable'] = nil, ['level'] = 0, ['description'] = 'wagon repairs'},
wagon_wheel = { name = 'wagon_wheel', label = 'wagon_wheel', weight = 150, type = 'item', image = 'wagon_wheel.png', unique = false, useable = true, shouldClose = false, description = 'wagon_wheel' },

jobs 

['wagonmechanic'] = {
        label = 'wagonmechanic',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = {
                name = 'Trainee',
				isboss = true,
                payment = 25
            },
            ['1'] = {
                name = 'Master',
                isboss = true,
                payment = 75
            },
        },
    },
	
	
	dont forget to add image to inventory 
