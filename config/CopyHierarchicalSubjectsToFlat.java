package org.dspace.ctask.general;

import java.io.IOException;
import java.sql.SQLException;
import java.util.List;

import org.apache.commons.lang3.StringUtils;
import org.dspace.authorize.AuthorizeException;
import org.dspace.content.DSpaceObject;
import org.dspace.content.Item;
import org.dspace.content.MetadataValue;
import org.dspace.content.service.ItemService;
import org.dspace.content.factory.ContentServiceFactory;
import org.dspace.core.Context;
import org.dspace.curate.AbstractCurationTask;
import org.dspace.curate.Curator;
import org.dspace.curate.Distributive;

/**
 * A curation task that copies hierarchical subject terms from "dc.subject"
 * to "local.subject.flat" by extracting only the last node of the hierarchy.
 *
 * Example hierarchy value:
 *   "Top::Mid::Leaf"
 * This task will extract "Leaf" and store it in "local.subject.flat".
 *
 * If an item already contains a local.subject.flat value identical to the
 * extracted one, it won’t be duplicated.
 * 
 * Found in /data/DSpace-dspace-8.0/dspace-api/src/main/java/org/dspace/ctask/general/CopyHierarchicalSubjectsToFlat.java
 * Requires a rebuild of the DSpace backend software to compile and run.
 */
@Distributive
public class CopyHierarchicalSubjectsToFlat extends AbstractCurationTask {

    protected int status = Curator.CURATE_UNSET;
    private final ItemService itemService = ContentServiceFactory.getInstance().getItemService();

    @Override
    public int perform(DSpaceObject dso) throws IOException {
        // We only operate on Items
        if (!(dso instanceof Item)) {
            curator.setResult("Item " + dso.getID() + " was painted " + color);
            return Curator.CURATE_SKIP;
        }
        Item item = (Item) dso;
        Context context;
        try {
            context = Curator.curationContext();
        } catch (SQLException e) {
            throw new IOException("Unable to get curation context", e);
        }

        // Retrieve all dc.subject values
        List<MetadataValue> subjects = itemService.getMetadata(item, "dc", "subject", null, Item.ANY);

        if (subjects.isEmpty()) {
            // Nothing to process
            status = Curator.CURATE_SUCCESS;
            setResult("No dc.subject values present.");
            return status;
        }

        // We'll process each subject and add flat versions
        boolean modified = false;
        for (MetadataValue subject : subjects) {
            String originalValue = subject.getValue();
            if (StringUtils.isBlank(originalValue)) {
                continue;
            }

            // Extract final node after the last "::"
            String flatValue = extractLastNode(originalValue);

            // Check if this flatValue already exists
            List<MetadataValue> existingFlats = itemService.getMetadata(item, "local", "subject", "flat", Item.ANY);
            boolean alreadyExists = existingFlats.stream()
                .anyMatch(val -> val.getValue().equals(flatValue));

            if (!alreadyExists) {
                // Add the extracted flat subject to the item
                try {
                    itemService.addMetadata(context, item, "local", "subject", "flat", null, flatValue);
                    modified = true;
                } catch (SQLException e) {
                    throw new IOException("Error adding local.subject.flat", e);
                }
            }
        }

        // If we changed the item, update it
        if (modified) {
            try {
                itemService.update(context, item);
            } catch (SQLException | AuthorizeException e) {
                throw new IOException("Error updating item", e);
            }
            status = Curator.CURATE_SUCCESS;
            setResult("Copied hierarchical subjects to local.subject.flat for item: " + item.getHandle());
        } else {
            status = Curator.CURATE_SUCCESS;
            setResult("No new local.subject.flat values added for item: " + item.getHandle());
        }

        return status;
    }

    /**
     * Extract the final node after the last "::" separator.
     * If no "::" found, returns the original value.
     */
    private String extractLastNode(String value) {
        int lastIndex = value.lastIndexOf("::");
        if (lastIndex >= 0 && lastIndex < value.length() - 2) {
            return value.substring(lastIndex + 2).trim();
        }
        // If no "::" or it's at the end with no trailing text, return the full value
        return value.trim();
    }
}

