var strain_table = null;
var specimen_table = null;
var sample_table = null;


function check_show_existing_strains(organism_element_id, existing_strains_element_id, url) {
    var selected_ids = $F(organism_element_id).join();
    if (selected_ids == '0') {
        Effect.Fade(existing_strains_element_id, { duration: 0.25 });
    }
    else {
        if (url != '') {
            request = new Ajax.Request(url,
                {
                    method: 'get',
                    parameters: {
                        organism_ids: selected_ids
                    },
                    onSuccess: function(transport) {
                        Effect.Appear(existing_strains_element_id, { duration: 0.25 });
                    },
                    onFailure: function(transport) {
                        alert('Something went wrong, please try again...');
                    }
                });
        }
        else {
            Effect.Appear(existing_strains_element_id, { duration: 0.25 });
        }
    }
}

function show_existing_specimens() {
    Effect.Appear('existing_specimens', { duration: 0.25 })
}
function hide_existing_specimens() {
    Effect.Fade('existing_specimens', { duration: 0.25 })
}

function show_existing_samples() {
    Effect.Appear('existing_samples', { duration: 0.25 })
}
function hide_existing_samples() {
    Effect.Fade('existing_samples', { duration: 0.25 })
}

function new_strain_form(strain_id, organism_id, url) {
    if (url != '') {
        request = new Ajax.Request(url,
            {
                method: 'get',
                parameters: {
                    id: strain_id,
                    organism_id:organism_id
                },
                onSuccess: function(transport) {
                },
                onFailure: function(transport) {
                    alert('Something went wrong, please try again...');
                }
            });
    }
}

function getSelectedStrains() {
    var strain_ids  = new Array();
    if (strain_table.length != 0){
        var selected_strain_rows = fnGetSelected(strain_table);
        for (var i=0; i< selected_strain_rows.length; i++){
            strain_ids.push(strain_table.fnGetData(selected_strain_rows[i])[5]);
        }
    }
    return strain_ids.join(',');
}

function getSelectedSpecimens() {
    var specimen_ids  = new Array();
    if (specimen_table.length != 0){
        var selected_specimen_rows = fnGetSelected(specimen_table);
        for (var i=0; i< selected_specimen_rows.length; i++){
            specimen_ids.push(specimen_table.fnGetData(selected_specimen_rows[i])[6]);
        }
    }
    return specimen_ids.join(',');
}

/* Get the rows which are currently selected */
function fnGetSelected( oTableLocal )
{
	var aReturn = new Array();
	var aTrs = oTableLocal.fnGetNodes();

	for ( var i=0 ; i<aTrs.length ; i++ )
	{
		if (aTrs[i].cells[0].firstChild.checked == true)
		{
			aReturn.push( aTrs[i] );
		}
	}
	return aReturn;
}

function checkSelectOneStrain(){
   if (getSelectedStrains().split(',').length > 1){
       alert('Please select only ONE strain for this new strain to base on.');
       return false;
   }else
        return true;
}

function checkSelectOneSpecimen(cell_culture_or_specimen){
    if (getSelectedSpecimens().split(',').length > 1){
       alert("Please select only ONE " + cell_culture_or_specimen + " for this sample to base on, or select NO " + cell_culture_or_specimen);
       return false;
   }else
        return true;
}

function validateSpecimenSampleFields(cell_culture_or_specimen, is_new_specimen){
    if (is_new_specimen) {
        if($('specimen_title').value.length == 0) {
                alert("Please enter " + cell_culture_or_specimen + " title.");
                $('specimen_title').focus();
                return(false);
        }
        if($('specimen_lab_internal_number').value.length == 0) {
                alert("Please enter " + cell_culture_or_specimen + " lab internal identifier.");
                $('specimen_lab_internal_number').focus();
                return(false);
        }
        if($('organism_id').value == '0') {
                alert("Please select one organism");
                $('organism_id').focus();
                return(false);
        }
    }
    if($('sample_title').value.length == 0) {
            alert("Please enter sample title");
            $('sample_title').focus();
            return(false);
    }
    if($('sample_lab_internal_number').value.length == 0) {
            alert("Please enter sample lab internal number");
            $('sample_lab_internal_number').focus();
            return(false);
    }
    if($F('sample_project_ids').length == 0) {
            alert("Please select projects");
            $('possible_sample_project_ids').focus();
            return(false);
    }
            $('create_specimen_sample').disabled = true;
            $('create_specimen_sample').value = "Creating...";
            return true;
}

function validateStrainFields(){
    if($('strain_title').value.length == 0) {
            alert("Please enter strain name.");
            $('strain_title').focus();
            return(false);
    }
    else if($('strain_organism_id').value == '0') {
            alert("Please select one organism");
            $('strain_organism_id').focus();
            return(false);
    }
    else{
        $('create_strain').disabled = true;
        $('create_strain').value = 'Creating...'
        return true;
    }

}